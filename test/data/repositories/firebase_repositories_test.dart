// Unit tests for the Firebase repository implementations (Task 8.7).
//
// These repositories (`FirebaseServiceRepository`, `FirebaseOrderRepository`,
// `FirebaseChatRepository`) talk to Cloud Firestore / Firebase Storage, which
// cannot be spun up inside the pure Dart/Flutter test harness — and the
// `fake_cloud_firestore` package is intentionally NOT a dependency (the
// network is restricted, so no new packages can be added). Rather than fake the
// entire Firestore SDK, these tests target the parts of each repository that
// are decidable WITHOUT a live backend:
//
//   * ServiceRepository — the offline cache-fallback filter. `watchServices`
//     re-applies an "active-only + optional category" filter to the Hive cache
//     when the live stream errors. That filter is exposed via the
//     `@visibleForTesting cachedListings(...)` seam and exercised here against a
//     REAL `LocalSource` (temp Hive box + mock SharedPreferences), so the
//     offline behavior (Requirements 6.8, 17.1) is verified with no mocks of
//     our own code (Firestore is supplied as an unused mock).
//
//   * OrderRepository — its lifecycle collaborator, `DefaultOrderService`. The
//     repository delegates ALL order-construction and transition rules to the
//     service: `createOrder` builds the initial order via `buildInitialOrder`
//     and `updateStatus` validates via `appendStatusEvent`. We assert those
//     collaborator semantics directly (pending status + single timeline event;
//     illegal transitions rejected without mutation — Requirements 8.6, 10A.4).
//     We also cover the one repository-level branch reachable without Firestore:
//     `createOrder` rejecting an unauthenticated caller before any I/O.
//
//   * Chat — the pure unread-accounting routing. `sendMessage` increments the
//     RECIPIENT's counter and `markRead` zeroes the READER's counter; the
//     side-selection is exposed via the `@visibleForTesting`
//     `recipientUnreadFieldFor` / `readerUnreadFieldFor` seams and asserted here
//     (Requirements 12.1, 12.2).
//
// Behaviors that genuinely require Firestore round-trips (live `snapshots()`
// streaming, transactional writes, document persistence) are intentionally
// out of scope here and are covered by the Firebase-emulator integration tests
// in Task 24.2. Such spots are flagged with a `TODO(task-24.2)` comment.
//
// _Requirements: 6.8, 17.1, 8.6, 12.1_

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/order.dart';
import 'package:keyframes_app/data/models/order_draft.dart';
import 'package:keyframes_app/data/models/order_status_event.dart';
import 'package:keyframes_app/data/models/service_listing.dart';
import 'package:keyframes_app/data/repositories/firebase_chat_repository.dart';
import 'package:keyframes_app/data/repositories/firebase_order_repository.dart';
import 'package:keyframes_app/data/repositories/firebase_service_repository.dart';
import 'package:keyframes_app/data/sources/local_source.dart';
import 'package:keyframes_app/features/order/default_order_service.dart';

/// A Firestore stand-in that is never actually called by the code paths under
/// test. Both `FirebaseServiceRepository.cachedListings` (cache-only) and the
/// unauthenticated branch of `FirebaseOrderRepository.createOrder` run before
/// any Firestore access, so this mock needs no stubbed behavior — it merely
/// satisfies the constructor's required dependency.
class _MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

void main() {
  // shared_preferences' mock channel and Hive both need the test binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // ServiceRepository — offline cache-fallback filtering (Req 6.8, 17.1)
  // ===========================================================================
  group('FirebaseServiceRepository cache fallback (Req 6.8, 17.1)', () {
    late Directory tempDir;
    late Box<String> catalogBox;
    late SharedPreferences preferences;
    late LocalSource local;
    late FirebaseServiceRepository repository;

    /// A catalog mixing active/inactive listings across both categories so the
    /// active-only + category filter has something to actually exclude.
    List<ServiceListing> seedCatalog() => <ServiceListing>[
          const ServiceListing(
            id: 'it_active_1',
            title: 'Mobile App Development',
            tagline: 'Ship to the store',
            description: 'End-to-end Flutter build.',
            category: ServiceCategory.itServices,
            basePrice: 1499,
          ),
          const ServiceListing(
            id: 'it_active_2',
            title: 'Website Build',
            tagline: 'A site that converts',
            description: 'Responsive marketing site.',
            category: ServiceCategory.itServices,
            basePrice: 899,
          ),
          const ServiceListing(
            id: 'it_inactive',
            title: 'Legacy IoT Project',
            tagline: 'Retired offering',
            description: 'No longer offered.',
            category: ServiceCategory.itServices,
            basePrice: 500,
            active: false,
          ),
          const ServiceListing(
            id: 'gd_active',
            title: 'Logo Creation',
            tagline: 'A mark that sticks',
            description: 'Three concepts, vector delivery.',
            category: ServiceCategory.graphicDesign,
            basePrice: 199,
          ),
          const ServiceListing(
            id: 'gd_inactive',
            title: 'Old Poster Pack',
            tagline: 'Discontinued',
            description: 'No longer offered.',
            category: ServiceCategory.graphicDesign,
            basePrice: 79,
            active: false,
          ),
        ];

    setUpAll(() {
      tempDir = Directory.systemTemp.createTempSync('kf_repo_service_');
      Hive.init(tempDir.path);
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      preferences = await SharedPreferences.getInstance();

      catalogBox = await Hive.openBox<String>(LocalSource.catalogBoxName);
      await catalogBox.clear();

      local = LocalSource(catalogBox: catalogBox, preferences: preferences);
      await local.init();

      repository = FirebaseServiceRepository(
        firestore: _MockFirebaseFirestore(),
        local: local,
      );
    });

    tearDown(() async {
      await catalogBox.clear();
      await catalogBox.close();
    });

    tearDownAll(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('returns an empty list when nothing is cached', () {
      expect(repository.cachedListings(), isEmpty);
    });

    test('without a category, surfaces only ACTIVE listings', () async {
      await local.writeCatalog(seedCatalog());

      final result = repository.cachedListings();

      expect(
        result.map((l) => l.id),
        unorderedEquals(<String>['it_active_1', 'it_active_2', 'gd_active']),
      );
      // Every surfaced listing must be active (inactive ones are filtered out).
      expect(result.every((l) => l.active), isTrue);
      expect(result.map((l) => l.id), isNot(contains('it_inactive')));
      expect(result.map((l) => l.id), isNot(contains('gd_inactive')));
    });

    test('with a category, surfaces only ACTIVE + matching-category listings',
        () async {
      await local.writeCatalog(seedCatalog());

      final itOnly =
          repository.cachedListings(category: ServiceCategory.itServices);
      expect(
        itOnly.map((l) => l.id),
        unorderedEquals(<String>['it_active_1', 'it_active_2']),
      );
      expect(
        itOnly.every((l) =>
            l.active && l.category == ServiceCategory.itServices),
        isTrue,
      );

      final gdOnly =
          repository.cachedListings(category: ServiceCategory.graphicDesign);
      expect(gdOnly.map((l) => l.id), <String>['gd_active']);
      expect(
        gdOnly.every((l) =>
            l.active && l.category == ServiceCategory.graphicDesign),
        isTrue,
      );
    });

    test('an all-inactive cache yields nothing regardless of category',
        () async {
      await local.writeCatalog(const <ServiceListing>[
        ServiceListing(
          id: 'x',
          title: 'Retired',
          tagline: 't',
          description: 'd',
          category: ServiceCategory.itServices,
          basePrice: 1,
          active: false,
        ),
      ]);

      expect(repository.cachedListings(), isEmpty);
      expect(
        repository.cachedListings(category: ServiceCategory.itServices),
        isEmpty,
      );
    });

    // TODO(task-24.2): The live `watchServices` stream path — write-through
    // caching on each snapshot and emitting the cached fallback when the
    // Firestore stream errors — requires a live/emulated Firestore and is
    // covered by the Firebase-emulator integration tests in Task 24.2.
  });

  // ===========================================================================
  // OrderRepository — delegation to its lifecycle collaborator (Req 8.6, 10A.4)
  // ===========================================================================
  group('FirebaseOrderRepository collaborator semantics (Req 8.6, 10A.4)', () {
    const DefaultOrderService service = DefaultOrderService();
    final DateTime base = DateTime.utc(2024, 1, 1, 12);

    OrderDraft validDraft() => OrderDraft(
          serviceId: 'service-1',
          serviceTitle: 'Logo Design',
          packageTier: PackageTier.premium,
          requirements: 'A clean modern logo for my startup brand.',
          deadline: base.add(const Duration(days: 7)),
        );

    // The repository's `createOrder` builds the order entirely via
    // `buildInitialOrder(id, clientId, draft)` and then persists it; the
    // persistence is the only Firestore-touching step. We assert the exact
    // construction defaults the repository relies on.
    test('createOrder defaults: a pending order with one pending timeline event',
        () {
      final Order order = service.buildInitialOrder(
        id: 'order-doc-id',
        clientId: 'client-7',
        draft: validDraft(),
        now: base,
      );

      expect(order.id, 'order-doc-id');
      expect(order.clientId, 'client-7');
      expect(order.serviceId, 'service-1');
      expect(order.status, OrderStatus.pending);
      expect(order.timeline, hasLength(1));
      expect(order.timeline.single.status, OrderStatus.pending);
      // The repository keeps `status == timeline.last.status` as an invariant.
      expect(order.status, order.timeline.last.status);
    });

    // The repository's `updateStatus` reads the order, then calls
    // `appendStatusEvent`. An illegal transition throws BEFORE the Firestore
    // write, so the stored order is left untouched (Requirement 10A.4).
    test('updateStatus rejects an illegal transition without mutation', () {
      final Order pending = Order(
        id: 'order-1',
        clientId: 'client-1',
        serviceId: 'service-1',
        serviceTitle: 'Logo Design',
        packageTier: PackageTier.standard,
        requirements: 'A clean modern logo for my brand.',
        status: OrderStatus.pending,
        createdAt: base,
        timeline: <OrderStatusEvent>[
          OrderStatusEvent(status: OrderStatus.pending, at: base),
        ],
      );

      // pending -> completed skips the lifecycle and must be rejected.
      expect(
        () => service.appendStatusEvent(pending, OrderStatus.completed),
        throwsA(isA<InvalidOrderTransitionException>()),
      );
      // Input is unchanged: no write would have happened in the repository.
      expect(pending.status, OrderStatus.pending);
      expect(pending.timeline, hasLength(1));
    });

    test('updateStatus accepts a legal transition and appends one event', () {
      final Order pending = Order(
        id: 'order-1',
        clientId: 'client-1',
        serviceId: 'service-1',
        serviceTitle: 'Logo Design',
        packageTier: PackageTier.standard,
        requirements: 'A clean modern logo for my brand.',
        status: OrderStatus.pending,
        createdAt: base,
        timeline: <OrderStatusEvent>[
          OrderStatusEvent(status: OrderStatus.pending, at: base),
        ],
      );

      final Order next = service.appendStatusEvent(
        pending,
        OrderStatus.inReview,
        at: base.add(const Duration(hours: 1)),
      );

      expect(next.status, OrderStatus.inReview);
      expect(next.timeline, hasLength(2));
      expect(next.status, next.timeline.last.status);
    });

    test('createOrder rejects an unauthenticated caller before any Firestore I/O',
        () async {
      // currentUserId returns null -> the repository throws StateError before
      // touching Firestore, so the unused mock is never called.
      final repository = FirebaseOrderRepository(
        orderService: service,
        currentUserId: () => null,
        firestore: _MockFirebaseFirestore(),
      );

      await expectLater(
        () => repository.createOrder(validDraft()),
        throwsA(isA<StateError>()),
      );
    });

    test('createOrder rejects an empty client id before any Firestore I/O',
        () async {
      final repository = FirebaseOrderRepository(
        orderService: service,
        currentUserId: () => '',
        firestore: _MockFirebaseFirestore(),
      );

      await expectLater(
        () => repository.createOrder(validDraft()),
        throwsA(isA<StateError>()),
      );
    });

    // TODO(task-24.2): The full create/read/update Firestore round-trips
    // (document persistence, `watchClientOrders` scoping, status write +
    // client notification) are covered by the Firebase-emulator integration
    // tests in Task 24.2.
  });

  // ===========================================================================
  // Chat — unread accounting routes to the recipient/reader (Req 12.1, 12.2)
  // ===========================================================================
  group('FirebaseChatRepository unread accounting (Req 12.1, 12.2)', () {
    const String clientId = 'client-123';
    const String adminId = 'admin-999';

    group('sendMessage increments the RECIPIENT (Req 12.1)', () {
      test('a client sender bumps the admin counter', () {
        expect(
          FirebaseChatRepository.recipientUnreadFieldFor(
            conversationClientId: clientId,
            senderId: clientId,
          ),
          'unreadAdmin',
        );
      });

      test('an admin (non-client) sender bumps the client counter', () {
        expect(
          FirebaseChatRepository.recipientUnreadFieldFor(
            conversationClientId: clientId,
            senderId: adminId,
          ),
          'unreadClient',
        );
      });

      test('a null conversation clientId defaults the recipient to the client',
          () {
        expect(
          FirebaseChatRepository.recipientUnreadFieldFor(
            conversationClientId: null,
            senderId: adminId,
          ),
          'unreadClient',
        );
      });

      test('the recipient is always the OTHER side of the sender', () {
        final clientSendsTo = FirebaseChatRepository.recipientUnreadFieldFor(
          conversationClientId: clientId,
          senderId: clientId,
        );
        final adminSendsTo = FirebaseChatRepository.recipientUnreadFieldFor(
          conversationClientId: clientId,
          senderId: adminId,
        );
        expect(clientSendsTo, isNot(adminSendsTo));
      });
    });

    group('markRead zeroes the READER own counter (Req 12.2)', () {
      test('the client reader clears the client counter', () {
        expect(
          FirebaseChatRepository.readerUnreadFieldFor(
            conversationClientId: clientId,
            readerId: clientId,
          ),
          'unreadClient',
        );
      });

      test('an admin reader clears the admin counter', () {
        expect(
          FirebaseChatRepository.readerUnreadFieldFor(
            conversationClientId: clientId,
            readerId: adminId,
          ),
          'unreadAdmin',
        );
      });

      test('reader resets its OWN side, opposite of the send recipient', () {
        // When the client sends, the admin is the recipient; when the client
        // reads, the client clears its own counter. The two must differ.
        final clientSendRecipient =
            FirebaseChatRepository.recipientUnreadFieldFor(
          conversationClientId: clientId,
          senderId: clientId,
        );
        final clientReadField = FirebaseChatRepository.readerUnreadFieldFor(
          conversationClientId: clientId,
          readerId: clientId,
        );
        expect(clientReadField, 'unreadClient');
        expect(clientSendRecipient, 'unreadAdmin');
        expect(clientReadField, isNot(clientSendRecipient));
      });
    });

    // TODO(task-24.2): The transactional `sendMessage` write (message persisted
    // + conversation meta updated + `FieldValue.increment(1)` applied to the
    // recipient field) and the batched `markRead` write require a live/emulated
    // Firestore and are covered by the Firebase-emulator integration tests in
    // Task 24.2.
  });
}
