import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keyframes_app/app/providers.dart';
import 'package:keyframes_app/data/models/app_user.dart';
import 'package:keyframes_app/data/models/enums.dart';
import 'package:keyframes_app/data/models/service_listing.dart';
import 'package:keyframes_app/features/catalog/catalog_controller.dart';
import 'package:keyframes_app/features/catalog/home_screen.dart';

/// Widget tests for the client home / service-catalog screen ([HomeScreen]).
///
/// These tests exercise the screen's four user-visible states — loading,
/// loaded (with a category filter), empty, and offline — entirely against
/// in-memory Riverpod overrides, so no Firebase / network / Hive cache is ever
/// touched. The catalog itself is a `family` [StreamProvider]
/// (`catalogControllerProvider`), so each test overrides the exact family
/// argument the screen will watch (driven by [selectedCategoryProvider]) with a
/// hand-rolled stream that pins the screen to the desired [AsyncValue] state.
///
/// Validates: Requirements 6.3, 6.4, 6.6, 6.7
void main() {
  // A signed-in client so the greeting header renders a real name rather than
  // the "there" fallback. Injected via [currentUserProvider].
  final AppUser testUser = AppUser(
    id: 'u1',
    name: 'Ada Lovelace',
    email: 'ada@example.com',
    createdAt: DateTime(2024, 1, 1),
  );

  // Thumbnails are intentionally null so the cards render the local
  // placeholder instead of issuing a (forbidden) network image request.
  const ServiceListing itListing = ServiceListing(
    id: 's-it',
    title: 'Flutter App Build',
    tagline: 'Cross-platform mobile apps',
    description: 'We build your mobile app end to end.',
    category: ServiceCategory.itServices,
    basePrice: 1200,
  );

  const ServiceListing designListing = ServiceListing(
    id: 's-gd',
    title: 'Brand Logo Design',
    tagline: 'A logo that pops',
    description: 'Custom logo design for your brand.',
    category: ServiceCategory.graphicDesign,
    basePrice: 300,
  );

  /// Hosts [HomeScreen] under a [ProviderScope] with the given [overrides].
  ///
  /// The screen is wrapped in a [MaterialApp] (for Directionality / Material /
  /// MediaQuery ancestors) and an inner [MediaQuery] that disables animations,
  /// so the staggered card entrance reveals instantly (no pending delay timers)
  /// and the content is asserted on the first frame.
  Widget host(List<Override> overrides) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Builder(
          builder: (BuildContext context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const HomeScreen(),
          ),
        ),
      ),
    );
  }

  testWidgets(
      'loading state shows the catalog shimmer skeleton (Requirement 6.4)',
      (WidgetTester tester) async {
    // A stream that never emits keeps the StreamProvider in AsyncLoading.
    final Completer<List<ServiceListing>> never =
        Completer<List<ServiceListing>>();

    await tester.pumpWidget(
      host(<Override>[
        currentUserProvider.overrideWithValue(testUser),
        // Default selected category is null -> override the null family.
        catalogControllerProvider(null).overrideWith(
          (ref) => Stream<List<ServiceListing>>.fromFuture(never.future),
        ),
      ]),
    );
    // A single frame is enough to render the loading branch; the shimmer keeps
    // animating so we deliberately avoid pumpAndSettle.
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('catalogLoading')),
      findsOneWidget,
    );
    // The greeting still renders above the loading body.
    expect(find.text('Ada'), findsOneWidget);
  });

  testWidgets(
      'data state with an active category filter renders the matching card '
      '(Requirement 6.3)', (WidgetTester tester) async {
    await tester.pumpWidget(
      host(<Override>[
        currentUserProvider.overrideWithValue(testUser),
        // Select the IT Services chip; the screen will watch the itServices
        // family argument, which a filtered repository would serve.
        selectedCategoryProvider
            .overrideWith((ref) => ServiceCategory.itServices),
        catalogControllerProvider(ServiceCategory.itServices).overrideWith(
          (ref) => Stream<List<ServiceListing>>.value(
            const <ServiceListing>[itListing],
          ),
        ),
      ]),
    );
    await tester.pump();

    // The IT listing's title is shown (it appears in both the featured carousel
    // and the grid), while the graphic-design listing — absent from the
    // filtered stream — does not render.
    expect(find.text('Flutter App Build'), findsWidgets);
    expect(find.text('Brand Logo Design'), findsNothing);
  });

  testWidgets('empty state shows the friendly empty message (Requirement 6.7)',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      host(<Override>[
        currentUserProvider.overrideWithValue(testUser),
        catalogControllerProvider(null).overrideWith(
          (ref) => Stream<List<ServiceListing>>.value(
            const <ServiceListing>[],
          ),
        ),
      ]),
    );
    await tester.pump();

    expect(find.text('No services available yet'), findsOneWidget);
  });

  testWidgets(
      'offline state shows the offline banner above the catalog '
      '(Requirement 6.6)', (WidgetTester tester) async {
    await tester.pumpWidget(
      host(<Override>[
        currentUserProvider.overrideWithValue(testUser),
        // Force the offline flag on and serve cached listings beneath it.
        catalogOfflineProvider.overrideWith((ref) => true),
        catalogControllerProvider(null).overrideWith(
          (ref) => Stream<List<ServiceListing>>.value(
            const <ServiceListing>[designListing],
          ),
        ),
      ]),
    );
    await tester.pump();

    expect(
      find.text("You're offline — showing saved services."),
      findsOneWidget,
    );
  });
}
