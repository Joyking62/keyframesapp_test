# Implementation Plan: Keyframes App

## Overview

This plan converts the Keyframes design into a series of incremental, test-driven coding steps for a cross-platform Flutter app. Work flows bottom-up: scaffolding and design system first, then immutable data models, repository interfaces with Firebase implementations and a Hive cache, then the bootstrap/router with role guards, and finally each feature (splash, onboarding, auth, catalog, detail, pre-order, chat, client dashboard, order lifecycle, admin dashboard) with its supporting animations. Each task builds on prior tasks and ends by wiring the new code into the running app so no code is left orphaned.

The design defines 8 correctness properties validated with Dart `glados` property-based tests, complemented by unit, widget, and integration tests. Test sub-tasks are marked optional with `*`.

> Language: **Dart 3.x / Flutter 3.x** (taken directly from the design — no language selection needed).

## Tasks

- [x] 1. Scaffold project, dependencies, and asset/config plumbing
  - Create the Flutter project structure under `lib/` matching the design's module/folder layout (`app/`, `core/`, `features/`, `data/`).
  - Add all dependencies to `pubspec.yaml`: `flutter_riverpod`, `riverpod_annotation`, `go_router`, `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `firebase_messaging`, `google_sign_in`, `freezed_annotation`, `json_annotation`, `hive`, `hive_flutter`, `shared_preferences`, `google_fonts`, `flutter_svg`, `cached_network_image`, `flutter_animate`, `flutter_form_builder`, `form_builder_validators`, `image_picker`, `intl`; dev deps `freezed`, `json_serializable`, `build_runner`, `riverpod_generator`, `glados`, `mocktail`, `integration_test`.
  - Register asset paths (`assets/images/`, `assets/animations/`) in `pubspec.yaml` and add a placeholder `keyframes_logo.png`/`.svg`.
  - Create a stub `main.dart` that runs a minimal `ProviderScope` app so the project compiles.
  - _Requirements: 13.6, 15.1_

- [x] 2. Build the design system (theme tokens, typography, spacing)
  - [x] 2.1 Implement color, spacing, radius, and elevation tokens
    - Create `core/theme/k_colors.dart` (`KColors`) and `core/theme/k_space.dart` (`KSpace`) with the exact navy/amber/white tokens and spacing/radius constants from the design.
    - _Requirements: 13.1, 13.3_

  - [x] 2.2 Implement typography and global ThemeData
    - Create `core/theme/k_text_styles.dart` using `google_fonts` (Poppins headings/brand, Inter body/UI) for the full type scale, and `buildKeyframesTheme()` wiring colors, text styles, radii, elevations, and a 48x48 minimum touch-target configuration.
    - _Requirements: 13.1, 13.2, 13.3, 13.4_

  - [x]* 2.3 Write unit tests for theme tokens and text styles
    - Assert color hex values, spacing constants, and that each named text style uses the expected font/size/weight.
    - _Requirements: 13.1, 13.2, 13.3_

- [x] 3. Define core enums, validators, and the Result/error utilities
  - [x] 3.1 Implement domain enums and validators
    - Create `core/utils/validators.dart` with email, name (2–60), phone (7–15 digits), requirements-length (>=10), future-deadline, and base-price (>=0) / title (3–80) validators.
    - Define shared enums (`UserRole`, `ServiceCategory`, `OrderStatus`, `PackageTier`, `MessageType`) in `data/models/enums.dart`.
    - _Requirements: 16.1, 16.2, 8.4_

  - [x] 3.2 Implement the shared Result/AsyncValue error wrapper and input sanitizer
    - Create `core/utils/result.dart` for uniform loading/data/error rendering and `core/utils/sanitizer.dart` to strip unsafe content from free-text before persistence.
    - _Requirements: 17.3, 16.4_

  - [x]* 3.3 Write unit tests for validators and sanitizer
    - Cover valid/invalid email, phone digit bounds, name bounds, requirements minimum length, future-deadline, base-price/title bounds, and unsafe-content stripping.
    - _Requirements: 16.1, 16.2, 16.4, 8.4_

- [x] 4. Implement freezed data models with JSON serialization
  - [x] 4.1 Implement AppUser, ServiceListing, and Order family models
    - Create freezed models `AppUser`, `ServiceListing`, `Order`, and `OrderStatusEvent` in `data/models/` with `fromJson`/`toJson` and run `build_runner`.
    - _Requirements: 16.3, 15.2_

  - [x] 4.2 Implement Conversation and Message models plus input DTOs
    - Create freezed `Conversation`, `Message`, and the input DTOs `RegisterInput`, `OrderDraft`, `SendMessageInput`, `BootstrapResult`.
    - _Requirements: 16.3_

  - [x]* 4.3 Write property test for model serialization round-trip
    - **Property: Serialization round-trip equivalence** (supports the design's `fromJson`/`toJson` correctness)
    - **Validates: Requirements 16.3**
    - Use `glados` to generate random instances of every model and assert `fromJson(toJson(x)) == x`.

- [x] 5. Define repository interfaces (domain layer)
  - Create abstract interfaces `AuthRepository`, `ServiceRepository`, `OrderRepository`, and `ChatRepository` in `data/repositories/` exactly as specified in the design.
  - Define the `Order_Service` domain contract for `isValidTransition`, status-event appending, and notification hooks.
  - _Requirements: 4.1, 6.1, 8.6, 9.1, 10A.1, 11.5_

- [x] 6. Implement the order status state machine and pre-order validation logic
  - [x] 6.1 Implement isValidTransition and status-timeline append logic
    - Create `features/order/order_service.dart` implementing `isValidTransition` (`pending → inReview → inProgress → completed`; any non-`completed` → `cancelled`) and a pure `appendStatusEvent` that keeps `status == timeline.last.status` and timestamps non-decreasing, rejecting illegal transitions without mutation.
    - _Requirements: 10A.1, 10A.2, 10A.3, 10A.4_

  - [x] 6.2 Implement pre-order draft validation
    - Add `validateDraft(OrderDraft)` enforcing requirements length >= 10, deadline (if set) > now, and a selected `PackageTier`; build the initial `Order` with status `pending` and a single `pending` timeline event.
    - _Requirements: 8.4, 8.6_

  - [x]* 6.3 Write property test for order status monotonicity
    - **Property 2: Order status monotonicity**
    - **Validates: Requirements 10A.2, 10A.3**
    - Generate random valid status-update sequences and assert `order.status == timeline.last.status` and non-decreasing timestamps.

  - [x]* 6.4 Write property test for valid-transitions-only
    - **Property 3: Valid transitions only**
    - **Validates: Requirements 10A.4**
    - Generate random (current, requested) status pairs; assert illegal transitions are rejected and leave the order unchanged.

  - [x]* 6.5 Write property test for pre-order validity
    - **Property 4: Pre-order validity**
    - **Validates: Requirements 8.4, 8.6**
    - Generate random drafts; assert every created Order has `requirements.length >= 10`, `deadline == null || deadline > createdAt`, and a non-null `packageTier`.

- [x] 7. Implement local cache (Hive) and preferences source
  - [x] 7.1 Implement Hive catalog cache and shared_preferences flags
    - Create `data/sources/local_source.dart`: open Hive boxes for the Cached_Catalog, persist/read `seenOnboarding` and theme/notification prefs, and expose read/write of cached `ServiceListing`s.
    - _Requirements: 1.3, 3.3, 3.4, 6.6, 17.1_

  - [x]* 7.2 Write unit tests for local source
    - Test round-trip of cached catalog and `seenOnboarding` persistence using an in-memory/temp Hive setup.
    - _Requirements: 3.4, 6.6_

- [x] 8. Implement Firebase remote sources and repository implementations
  - [x] 8.1 Implement AuthRepository (Firebase Auth + Google) with role resolution
    - Implement `FirebaseAuthRepository`: `authState()`, `signIn`, `register` (creates client-role profile doc), `signInWithGoogle`, `signOut`, `currentUser`, resolving role from the user profile document.
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.7_

  - [x] 8.2 Implement ServiceRepository (Firestore) with cache fallback
    - Implement `FirebaseServiceRepository`: `watchServices` (active-only by default, optional category), `getById`, admin `upsert`/`setActive`/`delete`; write-through to the Hive cache and fall back to cache on fetch failure.
    - _Requirements: 6.1, 6.3, 6.8, 11.5, 11.6, 17.1, 17.2_

  - [x] 8.3 Implement OrderRepository (Firestore) wired to the order service
    - Implement `FirebaseOrderRepository`: `createOrder`, `watchClientOrders`, `watchAllOrders`, `watchOrder`, and `updateStatus` (delegating transition validation + timeline append to the order service) with admin notification on update.
    - _Requirements: 8.6, 8.7, 10.1, 10.3, 10A.1, 10A.5, 11.2_

  - [x] 8.4 Implement ChatRepository (Firestore) with unread accounting
    - Implement `FirebaseChatRepository`: `ensureConversation`, `streamMessages`, `sendMessage` (well-formedness enforced, increments recipient unread, updates conversation meta), `watchAllConversations`, `markRead` (sets reader unread to 0); add Storage upload for attachments with file-type/size validation.
    - _Requirements: 9.1, 9.2, 9.4, 9.5, 9.6, 12.1, 12.2, 16.5_

  - [x]* 8.5 Write property test for message well-formedness
    - **Property 5: Message well-formedness**
    - **Validates: Requirements 9.4, 9.5**
    - Generate random `SendMessageInput`s; assert text messages require non-empty text and image/file messages require a `mediaUrl`, otherwise are rejected.

  - [x]* 8.6 Write property test for unread accuracy
    - **Property 6: Unread accuracy**
    - **Validates: Requirements 12.2**
    - Generate random message/markRead sequences against a fake Firestore; assert that after `markRead(conversationId, readerId)` the reader's unread counter equals 0.

  - [x]* 8.7 Write unit tests for repository implementations
    - Using `mocktail`/fakes, test active-only catalog filtering, cache fallback on fetch failure, order creation defaults, and unread increment to the recipient.
    - _Requirements: 6.8, 17.1, 8.6, 12.1_

- [x] 9. Wire Riverpod providers and dependency injection
  - Create provider definitions exposing each repository and the order service, plus `bootstrapProvider`; configure `ProviderScope` overrides for Firebase vs. fake implementations.
  - _Requirements: 17.3_

- [x] 10. Implement bootstrap and the go_router with role guards
  - [x] 10.1 Implement bootstrap() and resolveInitialRoute()
    - Implement `bootstrap()` (load `seenOnboarding`, current user, best-effort non-blocking catalog preload) returning `BootstrapResult`, and pure `resolveInitialRoute(result)` covering all onboarding/role combinations.
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7_

  - [x] 10.2 Implement go_router with _authRoleGuard and shell routes
    - Implement `buildRouter(ref)` with all routes, client and admin `ShellRoute`s with bottom navigation, and `_authRoleGuard` redirecting clients away from `/admin/**`, unauthenticated users to `/login`, and handling data-layer permission-denied with a redirect + toast.
    - _Requirements: 5.1, 5.2, 5.3, 5.4_

  - [x] 10.3 Wire MaterialApp.router and theme in app.dart
    - Implement `app/app.dart` with `MaterialApp.router` injecting `buildKeyframesTheme()` and the router; update `main.dart` to initialize Firebase + Hive then run the app.
    - _Requirements: 13.1_

  - [x]* 10.4 Write unit tests for resolveInitialRoute
    - Cover all four route decisions (onboarding, login, admin orders, client home) for every role/onboarding combination.
    - _Requirements: 1.4, 1.5, 1.6, 1.7_

  - [x]* 10.5 Write property test for role isolation
    - **Property 1: Role isolation**
    - **Validates: Requirements 5.1, 5.2**
    - Generate random (user state, target route) pairs; assert clients never resolve to `/admin/**` and unauthenticated users never resolve to a protected route.

- [x] 11. Checkpoint - core, data layer, and routing
  - Ensure all tests pass, ask the user if questions arise.

- [x] 12. Build the animation system and shared widgets
  - [x] 12.1 Implement reusable animation builders
    - Create `core/animations/`: shared-axis/fade-through route transitions, staggered fadeIn+slideY list entrance, count-up `TweenAnimationBuilder`, and a `disableAnimations`-aware wrapper that suppresses non-essential motion.
    - _Requirements: 14.1, 14.2, 14.4, 14.5_

  - [x] 12.2 Implement shared widgets
    - Create `KPrimaryButton` (gradient + loading morph + press scale), `KCard`, `KStatusChip` (OrderStatus → color/label), `KTilt3D` (perspective tilt on drag/scroll), `KShimmer`, and a `KErrorView` with retry.
    - _Requirements: 13.5, 14.3, 6.4, 17.4_

  - [x]* 12.3 Write widget tests for shared widgets
    - Test `KPrimaryButton` loading state swap, `KStatusChip` color/label mapping for each OrderStatus, and `KErrorView` retry callback.
    - _Requirements: 13.5, 17.4_

- [x] 13. Implement the 3D-depth animated splash / preloader
  - [x] 13.1 Implement SplashAnimator and buildDepthTransform
    - Implement `SplashAnimator` (entrance + idle sway controllers, depth/reveal/wordmark/tiltX/tiltY animations) and `buildDepthTransform` with the perspective `Matrix4` (scale 0.6→1.0, translateZ -400→0, tilt ±0.08 rad).
    - _Requirements: 2.1, 2.2, 2.3_

  - [x] 13.2 Build the SplashScreen widget tree and navigation
    - Compose the radial navy background, parallax glow, 3D logo with pulsing amber nodes, wordmark fade-in, and shimmer progress; implement `redirectAfterSplash` so navigation happens exactly once after both entrance completion AND bootstrap resolution.
    - _Requirements: 2.4, 2.5, 2.6_

  - [x]* 13.3 Write property test for splash determinism
    - **Property 7: Splash determinism**
    - **Validates: Requirements 2.5, 2.6**
    - Generate random orderings/timings of entrance-complete and bootstrap-resolve events; assert navigation fires exactly once and only after both complete.

  - [x]* 13.4 Write widget test for splash auto-navigation
    - With a fake bootstrap, assert the splash renders its layers and auto-navigates to the resolved route exactly once.
    - _Requirements: 2.4, 2.5_

- [x] 14. Implement onboarding
  - [x] 14.1 Build the onboarding pages and parallax
    - Implement three swipeable pages with offset-linked parallax illustrations, an amber-active page indicator, and "Skip"/"Get Started"; on completion persist `seenOnboarding=true` and navigate to login.
    - _Requirements: 3.1, 3.2, 3.3, 3.4_

  - [x]* 14.2 Write widget test for onboarding completion
    - Assert "Get Started"/"Skip" persists `seenOnboarding` and navigates to the login route.
    - _Requirements: 3.3_

- [x] 15. Implement authentication UI and controllers
  - [x] 15.1 Build login and register screens with AuthController
    - Implement the navy gradient header + slide-up form sheet, email/password + Google sign-in, register (name/email/phone), inline validation with error-shake, and loading-button morph; resolve role and route on success; sign-out returns to login. No role selector / admin signup exposed.
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8_

  - [x]* 15.2 Write widget tests for auth flows
    - Test invalid-submit shows inline error + shake without navigation, loading state during in-flight auth, and absence of any role/admin-signup control.
    - _Requirements: 4.5, 4.6, 4.8_

- [x] 16. Implement the service catalog
  - [x] 16.1 Implement CatalogController and home/catalog UI
    - Implement `CatalogController` (stream with optional category) and the home screen: greeting header, search bar, IT/Graphic-Design category chips, featured carousel (3D tilt cards), and active-only service card grid with thumbnail/title/tagline/price/category badge.
    - _Requirements: 6.1, 6.2, 6.3, 6.8_

  - [x] 16.2 Implement loading, empty, offline, and staggered-entrance states
    - Wire `KShimmer` while loading, staggered fade/slide card entrance, empty-state CTA, and cached-catalog + offline banner on fetch failure.
    - _Requirements: 6.4, 6.5, 6.6, 6.7, 17.1, 17.2_

  - [x]* 16.3 Write widget tests for catalog states
    - Test loading shimmer, category filtering, empty state, and offline-banner-with-cache rendering.
    - _Requirements: 6.3, 6.4, 6.6, 6.7_

- [x] 17. Implement service detail
  - [x] 17.1 Build the service detail screen
    - Implement the collapsing `SliverAppBar` hero, title/category/description/deliverables/gallery/timeline/price, Hero transition from the card thumbnail, and a sticky gradient "Pre-Order" CTA that opens the pre-order flow.
    - _Requirements: 7.1, 7.2, 7.3, 7.4_

  - [x]* 17.2 Write widget test for service detail CTA
    - Assert the sticky "Pre-Order" CTA navigates to the pre-order flow for the selected listing.
    - _Requirements: 7.4_

- [x] 18. Implement the multi-step pre-order flow
  - [x] 18.1 Implement PreOrderController and the three-step UI
    - Implement `PreOrderController` (setRequirements/setPackage/setDeadline/submit) and the animated horizontal stepper with slide transitions across requirements (with reference uploads), options (tier/deadline/budget), and contact-and-review steps.
    - _Requirements: 8.1, 8.2, 8.3_

  - [x] 18.2 Wire submission, success, and failure recovery
    - On submit, validate via the order service, create the Order (status `pending`, single timeline event, current client), notify admins, show the order-success screen with track/chat actions; on write failure show a non-blocking notice, retain the draft, and allow retry.
    - _Requirements: 8.4, 8.5, 8.6, 8.7, 8.8, 8.9_

  - [x]* 18.3 Write widget tests for pre-order validation and success
    - Test that invalid submissions show errors without creating an order and a valid submission shows the success screen.
    - _Requirements: 8.5, 8.8_

- [x] 19. Implement the real-time chat portal
  - [x] 19.1 Implement ChatController and the chat screen
    - Implement `ChatController` (stream messages, send with attachments) and the chat UI: client/company-styled bubbles, timestamps, attachments, image previews, typing indicator, read receipts; ensure a single conversation exists on open.
    - _Requirements: 9.1, 9.2, 9.3_

  - [x] 19.2 Wire send, well-formedness, animations, and attachment retry
    - Enforce non-empty text / required media on send, persist message + update conversation meta, increment recipient unread, animate bubble scale-and-fade with auto-scroll, and show a retry control on attachment upload failure.
    - _Requirements: 9.4, 9.5, 9.6, 9.7, 9.8, 12.1_

  - [x]* 19.3 Write widget test for chat send
    - Assert sending non-empty text appends a bubble and rejects empty-text sends.
    - _Requirements: 9.4, 9.7_

- [x] 20. Implement the client dashboard and order tracking
  - [x] 20.1 Build the orders, order-detail, and profile views
    - Implement orders grouped by status (Pending/In Progress/Completed/Cancelled) with chips + progress, client-scoped filtering, order detail (timeline, linked conversation, service info, requirements recap), and profile (edit, theme/notification prefs, sign-out); empty-state CTA when no orders.
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

  - [x]* 20.2 Write widget test for client-scoped orders and empty state
    - Assert only the current client's orders display and the empty-state CTA renders when none exist.
    - _Requirements: 10.3, 10.5_

- [x] 21. Checkpoint - client-facing features
  - Ensure all tests pass, ask the user if questions arise.

- [x] 22. Implement the admin dashboard
  - [x] 22.1 Build the admin overview with count-up KPIs
    - Implement KPI cards (new pre-orders, active chats, completed this month) using the count-up animation.
    - _Requirements: 11.1, 14.2_

  - [x] 22.2 Build admin orders management with status updates
    - Implement all-orders list with filter/search, status update (dropdown/drag) + internal note routed through the order service so transition validation applies.
    - _Requirements: 11.2, 11.3, 10A.1, 10A.4_

  - [x] 22.3 Build admin chats with unread badges
    - Implement the conversation list with per-conversation admin unread badges and open-to-reply.
    - _Requirements: 11.4, 12.3_

  - [x] 22.4 Build admin listings CRUD
    - Implement create/read/update/delete of `ServiceListing` (title, category, description, gallery, base price, active toggle) persisting through the data layer.
    - _Requirements: 11.5, 11.6_

  - [x]* 22.5 Write widget tests for admin orders and listings
    - Test that an admin status change is routed through the order service and that the active toggle persists.
    - _Requirements: 11.3, 11.6_

- [x] 23. Enforce the service-centric marketplace boundary
  - [x] 23.1 Audit routes, screens, and models for no per-employee surface
    - Add a guard/lint-style check ensuring no route, screen, or model exposes per-employee selection/hiring, and that every Order references a `ServiceListing`.
    - _Requirements: 15.1, 15.2_

  - [x]* 23.2 Write property test for no employee-hiring surface
    - **Property 8: No employee-hiring surface**
    - **Validates: Requirements 15.1, 15.2**
    - Enumerate the route table and model fields; assert none expose employee selection/hiring and every Order binds to a serviceId.

- [x] 24. Final integration, offline recovery, and end-to-end wiring
  - [x] 24.1 Wire offline-first recovery and connectivity retry
    - Connect connectivity changes to auto-retry catalog/chat fetches and ensure the shared Result pattern renders loading/data/error with retry across all features.
    - _Requirements: 17.1, 17.2, 17.3, 17.4_

  - [x]* 24.2 Write integration tests for happy paths
    - Using `integration_test` against the Firebase emulator: full pre-order happy path and a client↔admin chat round-trip.
    - _Requirements: 8.6, 9.2, 9.6, 10A.5_

- [x] 25. Final checkpoint - full test suite
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional test sub-tasks and can be skipped for a faster MVP.
- Each task references specific requirement sub-clauses for traceability.
- Checkpoints (11, 21, 25) ensure incremental validation at natural boundaries.
- Property-based tests (via Dart `glados`) validate the 8 universal correctness properties; unit, widget, and integration tests validate examples and edge cases.
- All 8 correctness properties are covered: Property 1 (10.5), Property 2 (6.3), Property 3 (6.4), Property 4 (6.5), Property 5 (8.5), Property 6 (8.6), Property 7 (13.3), Property 8 (23.2).

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1"] },
    { "id": 1, "tasks": ["2.1", "3.1", "3.2"] },
    { "id": 2, "tasks": ["2.2", "2.3", "3.3", "4.1", "4.2"] },
    { "id": 3, "tasks": ["4.3", "5", "7.1", "7.2"] },
    { "id": 4, "tasks": ["6.1", "6.2"] },
    { "id": 5, "tasks": ["6.3", "6.4", "6.5", "8.1", "8.2", "8.3", "8.4"] },
    { "id": 6, "tasks": ["8.5", "8.6", "8.7", "9", "12.1", "12.2"] },
    { "id": 7, "tasks": ["10.1", "10.2", "10.3", "12.3", "13.1"] },
    { "id": 8, "tasks": ["10.4", "10.5", "13.2", "14.1", "15.1", "16.1"] },
    { "id": 9, "tasks": ["13.3", "13.4", "14.2", "15.2", "16.2", "17.1"] },
    { "id": 10, "tasks": ["16.3", "17.2", "18.1", "19.1", "20.1"] },
    { "id": 11, "tasks": ["18.2", "19.2", "20.2", "22.1", "22.2", "22.3", "22.4"] },
    { "id": 12, "tasks": ["18.3", "19.3", "22.5", "23.1", "24.1"] },
    { "id": 13, "tasks": ["23.2", "24.2"] }
  ]
}
```
