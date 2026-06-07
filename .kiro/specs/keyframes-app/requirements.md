# Requirements Document

## Introduction

Keyframes is a cross-platform (iOS + Android) Flutter mobile application that operates as a **service marketplace** for the Keyframes startup. Unlike Fiverr-style platforms that connect clients to individual freelancers, Keyframes is service-centric: clients browse a curated catalog of the company's IT services (mobile app development, web development, IoT, university mini projects) and graphic-design services (video editing, poster editing, logo creation), place **pre-orders**, communicate with the company through an in-app **chat portal**, and track work from a **client dashboard**. The company administers incoming pre-orders, conversations, and listings through an **admin dashboard**.

These requirements are derived from the approved design document and capture the behavior of every feature it describes: onboarding, authentication & roles, the service catalog, service detail, the multi-step pre-order flow, the real-time chat portal, the client dashboard, the admin dashboard, the 3D-depth animated splash/preloader, the design system/branding, the animation strategy, and the system-wide correctness properties (role isolation, order status monotonicity, valid transitions, pre-order validity, message well-formedness, unread accuracy, splash determinism, and the no-employee-hiring surface).

Requirements use the EARS format and are intended to remain consistent with the design's layered architecture (presentation / domain / data), Riverpod state management, go_router navigation with role guards, and the Firebase-backed data layer abstracted behind repository interfaces.

## Glossary

- **Keyframes_App**: The complete Flutter mobile application, used when a requirement applies to the system as a whole.
- **Splash_Module**: The component that renders the 3D-depth animated preloader and performs application bootstrap.
- **Bootstrap_Service**: The logic (`bootstrap()` / `resolveInitialRoute`) that loads onboarding flags and the current user, then produces the initial route decision data.
- **Onboarding_Module**: The component presenting the three introductory pages and persisting the `seenOnboarding` flag.
- **Auth_Module**: The component handling sign-in, registration, Google sign-in, sign-out, and role resolution.
- **Router_Guard**: The go_router redirect logic (`_authRoleGuard`) that enforces authentication and role-based access.
- **Catalog_Module**: The component presenting the home/service catalog with category filtering and search.
- **Service_Detail_Module**: The component presenting a single service listing's full detail.
- **PreOrder_Module**: The multi-step pre-order flow and its submission logic (`PreOrderController` / `submitPreOrder`).
- **Order_Service**: The domain logic managing order creation, status updates, transition validation, and the status timeline.
- **Chat_Module**: The real-time client↔company chat portal and its controller/repository.
- **Client_Dashboard_Module**: The component presenting a client's orders, order detail, and profile.
- **Admin_Dashboard_Module**: The component presenting the admin overview, orders management, chats, and listings CRUD.
- **Design_System**: The centralized theme tokens (colors, typography, spacing, radius, elevation) and shared widgets.
- **Animation_System**: The shared animation builders and motion behaviors across screens.
- **AppUser**: A user entity with `id`, `name`, `email`, optional `phone`/`photoUrl`, a `role` (`client` or `admin`), and `createdAt`.
- **UserRole**: An enumeration with values `client` and `admin`.
- **ServiceListing**: A service catalog entry with `id`, `title`, `tagline`, `description`, `category`, `basePrice`, `deliverables`, `gallery`, `thumbnailUrl`, `active`, and `estimatedDays`.
- **ServiceCategory**: An enumeration with values `itServices` and `graphicDesign`.
- **Order**: A pre-order entity with `id`, `clientId`, `serviceId`, `serviceTitle`, `packageTier`, `requirements`, `attachments`, optional `budget`/`deadline`, `status`, `timeline`, and `createdAt`.
- **OrderStatus**: An enumeration with values `pending`, `inReview`, `inProgress`, `completed`, and `cancelled`.
- **OrderStatusEvent**: A timeline entry containing a `status`, optional `note`, and timestamp `at`.
- **PackageTier**: An enumeration with values `basic`, `standard`, and `premium`.
- **Conversation**: A single client↔company chat thread with `id`, `clientId`, `clientName`, `lastMessage`, `unreadClient`, `unreadAdmin`, and `updatedAt`.
- **Message**: A chat message with `id`, `conversationId`, `senderId`, `type`, optional `text`/`mediaUrl`, `sentAt`, and `read`.
- **MessageType**: An enumeration with values `text`, `image`, `file`, and `system`.
- **Valid_Transition**: An order status change permitted by the rule `pending → inReview → inProgress → completed`, plus any non-`completed` status → `cancelled`.
- **Cached_Catalog**: The locally stored (Hive) copy of the service catalog used for offline-first cold start.

## Requirements

### Requirement 1: Application Bootstrap and Initial Routing

**User Story:** As a user, I want the app to determine where to send me on launch, so that I land on the correct starting screen based on my onboarding and authentication state.

#### Acceptance Criteria

1. WHEN the Keyframes_App launches, THE Splash_Module SHALL invoke the Bootstrap_Service to load the `seenOnboarding` flag and the current AppUser.
2. THE Bootstrap_Service SHALL produce a bootstrap result containing the `seenOnboarding` flag and the current AppUser, which MAY be null.
3. WHILE the Bootstrap_Service is resolving, THE Bootstrap_Service SHALL attempt to preload the Cached_Catalog without blocking the bootstrap result.
4. IF the bootstrap result contains no AppUser AND `seenOnboarding` is false, THEN THE Bootstrap_Service SHALL resolve the initial route to the onboarding route.
5. IF the bootstrap result contains no AppUser AND `seenOnboarding` is true, THEN THE Bootstrap_Service SHALL resolve the initial route to the login route.
6. IF the bootstrap result contains an AppUser whose role is `admin`, THEN THE Bootstrap_Service SHALL resolve the initial route to the admin orders route.
7. IF the bootstrap result contains an AppUser whose role is `client`, THEN THE Bootstrap_Service SHALL resolve the initial route to the client home route.

### Requirement 2: 3D-Depth Animated Splash / Preloader

**User Story:** As a user, I want a premium animated splash featuring the Keyframes logo, so that the app feels polished from the first moment.

#### Acceptance Criteria

1. WHEN the Splash_Module is displayed, THE Splash_Module SHALL render the Keyframes logo using a `Matrix4` perspective transform that produces a 3D depth effect.
2. WHEN the splash entrance animation plays, THE Splash_Module SHALL scale the logo from 0.6 to 1.0 and translate it along the Z axis from -400 to 0 using an ease-out curve.
3. WHILE the entrance animation is complete, THE Splash_Module SHALL apply a looping idle sway that tilts the logo on the X and Y axes within the range -0.08 to 0.08 radians.
4. WHEN the splash is active, THE Splash_Module SHALL display the navy radial background, the parallax amber glow layer, the pulsing amber node overlay, the brand wordmark fade-in, and the bottom shimmer progress indicator.
5. WHEN both the entrance animation has completed AND the Bootstrap_Service has resolved, THE Splash_Module SHALL navigate exactly once to the resolved initial route.
6. WHILE either the entrance animation or the Bootstrap_Service has not completed, THE Splash_Module SHALL remain on the splash screen.

### Requirement 3: Onboarding

**User Story:** As a first-time user, I want a short introduction to the app, so that I understand what Keyframes offers before signing in.

#### Acceptance Criteria

1. WHEN a user reaches the Onboarding_Module, THE Onboarding_Module SHALL present three swipeable pages introducing browsing services, pre-ordering and tracking, and chatting directly with Keyframes.
2. WHILE a user swipes between onboarding pages, THE Onboarding_Module SHALL render parallax illustrations linked to the page scroll offset and a page indicator whose active dot is rendered in amber.
3. WHEN a user selects "Skip" or completes the final onboarding page with "Get Started", THE Onboarding_Module SHALL persist `seenOnboarding` as true and navigate to the login route.
4. WHERE `seenOnboarding` has been persisted as true, THE Keyframes_App SHALL NOT present the Onboarding_Module on subsequent launches.

### Requirement 4: Authentication and Role Resolution

**User Story:** As a client, I want to register and sign in securely, so that I can access my account, orders, and chats.

#### Acceptance Criteria

1. WHEN a user submits valid email and password credentials, THE Auth_Module SHALL authenticate the user and return the corresponding AppUser.
2. WHEN a user registers, THE Auth_Module SHALL collect name, email, and phone and create an AppUser with role `client`.
3. WHEN a user selects "Continue with Google", THE Auth_Module SHALL authenticate the user through Google sign-in and return the corresponding AppUser.
4. WHEN authentication succeeds, THE Auth_Module SHALL resolve the AppUser role from the user profile document.
5. IF a user submits credentials that fail validation or authentication, THEN THE Auth_Module SHALL display an inline error and play the error shake animation without navigating away.
6. WHILE an authentication request is in progress, THE Auth_Module SHALL display the submit button in its loading state.
7. WHEN a user requests sign-out, THE Auth_Module SHALL end the session and navigate to the login route.
8. THE Auth_Module SHALL NOT expose a role selector or an admin sign-up option to clients.

### Requirement 5: Role-Based Access Control

**User Story:** As the company, I want navigation guarded by role, so that clients cannot reach admin areas and unauthenticated users cannot reach protected screens.

#### Acceptance Criteria

1. IF an AppUser whose role is `client` attempts to resolve any admin route, THEN THE Router_Guard SHALL redirect the user to the client home route.
2. IF an unauthenticated user attempts to resolve a protected route, THEN THE Router_Guard SHALL redirect the user to the login route.
3. WHEN a permission-denied condition occurs at the data layer for a client accessing an admin operation, THE Keyframes_App SHALL redirect to the client home route and display a notification toast.
4. THE Admin_Dashboard_Module SHALL be reachable only by an AppUser whose role is `admin`.

### Requirement 6: Service Catalog Browsing

**User Story:** As a client, I want to browse and filter the service catalog, so that I can find the service I need.

#### Acceptance Criteria

1. WHEN the Catalog_Module is opened, THE Catalog_Module SHALL display a greeting header, a search bar, category chips for IT Services and Graphic Design, a featured carousel, and a list of service cards.
2. THE Catalog_Module SHALL render each service card with its thumbnail, title, tagline, starting price, and category badge.
3. WHEN a user selects a category chip, THE Catalog_Module SHALL display only ServiceListings whose category matches the selected ServiceCategory.
4. WHILE the catalog is loading, THE Catalog_Module SHALL display shimmer placeholder skeletons.
5. WHILE service cards enter the viewport, THE Animation_System SHALL apply a staggered fade-in and vertical-slide entrance.
6. IF the catalog fetch fails AND a Cached_Catalog exists, THEN THE Catalog_Module SHALL display the Cached_Catalog together with an offline banner.
7. IF the catalog contains no ServiceListings, THEN THE Catalog_Module SHALL display an empty state with a call to action to browse services.
8. THE Catalog_Module SHALL display only ServiceListings whose `active` value is true.

### Requirement 7: Service Detail

**User Story:** As a client, I want to view full details of a service, so that I can decide whether to pre-order it.

#### Acceptance Criteria

1. WHEN a user opens a ServiceListing, THE Service_Detail_Module SHALL display the hero image, title, category, description, deliverables list, sample gallery, estimated timeline, and starting price.
2. WHEN a user navigates from a service card to the Service_Detail_Module, THE Animation_System SHALL perform a Hero transition from the card thumbnail to the detail hero image.
3. THE Service_Detail_Module SHALL display a sticky bottom bar containing the gradient "Pre-Order" call-to-action.
4. WHEN a user taps the "Pre-Order" call-to-action, THE Service_Detail_Module SHALL open the PreOrder_Module for the selected ServiceListing.

### Requirement 8: Multi-Step Pre-Order Flow

**User Story:** As a client, I want to place a pre-order through a guided multi-step form, so that I can communicate my requirements, options, and contact details accurately.

#### Acceptance Criteria

1. WHEN the PreOrder_Module opens, THE PreOrder_Module SHALL present a three-step flow consisting of a requirements step, an options step, and a contact-and-review step.
2. WHILE a user moves between pre-order steps, THE PreOrder_Module SHALL display an animated horizontal stepper and slide transitions between steps.
3. THE PreOrder_Module SHALL collect a requirements description with reference uploads, a PackageTier, a deadline date, and a budget range.
4. WHEN a user submits the pre-order, THE PreOrder_Module SHALL validate that the requirements contain at least 10 characters, that the deadline (if set) is later than the current time, and that a PackageTier is selected.
5. IF pre-order validation fails, THEN THE PreOrder_Module SHALL reject the submission and display the corresponding validation error without creating an Order.
6. WHEN pre-order validation succeeds, THE Order_Service SHALL create an Order with status `pending`, a timeline containing one `pending` OrderStatusEvent, and the current AppUser as `clientId`.
7. WHEN an Order is created, THE Order_Service SHALL notify administrators of the new pre-order.
8. WHEN an Order is successfully created, THE PreOrder_Module SHALL display the order-success screen with options to track the order and to chat with the company.
9. IF the Order write fails, THEN THE PreOrder_Module SHALL display a non-blocking notification, retain the draft in memory, and allow the user to retry submission.

### Requirement 9: Real-Time Chat Portal

**User Story:** As a client, I want to chat directly with the Keyframes team, so that I can discuss my project in real time.

#### Acceptance Criteria

1. WHEN a client opens the Chat_Module, THE Chat_Module SHALL ensure a single Conversation exists between the client and the company.
2. WHEN a Conversation is open, THE Chat_Module SHALL stream its Messages in real time and rebuild the view on each update.
3. THE Chat_Module SHALL render client messages and company messages with distinct styling, timestamps, attachments, image previews, a typing indicator, and read receipts.
4. WHEN a user sends a text message, THE Chat_Module SHALL require non-empty text before adding the Message.
5. WHEN a user sends an image or file message, THE Chat_Module SHALL require a media reference before adding the Message.
6. WHEN a Message is added, THE Chat_Module SHALL persist the Message and update the Conversation metadata including its last message and updated timestamp.
7. WHEN a new Message is inserted into the view, THE Animation_System SHALL animate the message bubble with a scale-and-fade entrance and auto-scroll to the latest message.
8. IF an attachment upload fails, THEN THE Chat_Module SHALL mark the attachment as failed and display a retry control.

### Requirement 10: Client Dashboard and Order Tracking

**User Story:** As a client, I want a dashboard to track my orders and manage my profile, so that I can stay informed about my projects.

#### Acceptance Criteria

1. WHEN a client opens the orders view, THE Client_Dashboard_Module SHALL display the client's Orders grouped by status into Pending, In Progress, Completed, and Cancelled groups, each with a status chip and progress indicator.
2. WHEN a client opens an Order, THE Client_Dashboard_Module SHALL display the order timeline of status updates, the linked Conversation, the service information, and the requirements recap.
3. THE Client_Dashboard_Module SHALL display only Orders whose `clientId` matches the current AppUser.
4. WHEN a client opens the profile view, THE Client_Dashboard_Module SHALL allow editing the profile, adjusting theme and notification preferences, and signing out.
5. IF a client has no Orders, THEN THE Client_Dashboard_Module SHALL display an empty state with a call to action to browse services.

### Requirement 10A: Order Status Lifecycle

**User Story:** As the company, I want order status changes to be valid and auditable, so that clients always see an accurate, consistent order history.

#### Acceptance Criteria

1. WHEN an administrator updates an Order status, THE Order_Service SHALL append one OrderStatusEvent to the Order timeline with the new status, optional note, and the current timestamp.
2. THE Order_Service SHALL keep the Order's current `status` equal to the status of the most recent OrderStatusEvent in its timeline.
3. THE Order_Service SHALL append OrderStatusEvents such that each event's timestamp is greater than or equal to the previous event's timestamp.
4. IF a requested status update is not a Valid_Transition from the current status, THEN THE Order_Service SHALL reject the update without mutating the Order.
5. WHEN an Order status is updated, THE Order_Service SHALL notify the owning client of the status change.

### Requirement 11: Admin Dashboard

**User Story:** As an administrator, I want to manage pre-orders, conversations, and listings, so that I can run the Keyframes service operation.

#### Acceptance Criteria

1. WHEN an administrator opens the overview, THE Admin_Dashboard_Module SHALL display KPI cards for new pre-orders, active chats, and orders completed this month with a count-up animation.
2. WHEN an administrator opens orders management, THE Admin_Dashboard_Module SHALL display all Orders with filtering and search and SHALL allow updating an Order status and adding an internal note.
3. WHEN an administrator submits a status change, THE Admin_Dashboard_Module SHALL request the change through the Order_Service so that transition validation is applied.
4. WHEN an administrator opens the chats view, THE Admin_Dashboard_Module SHALL display all client Conversations with unread badges and SHALL allow opening a Conversation to reply.
5. WHEN an administrator manages listings, THE Admin_Dashboard_Module SHALL allow creating, reading, updating, and deleting a ServiceListing including its title, category, description, gallery, base price, and active toggle.
6. WHEN an administrator toggles a ServiceListing active state, THE Admin_Dashboard_Module SHALL persist the new `active` value through the Order_Service data layer.

### Requirement 12: Unread Message Tracking

**User Story:** As a user, I want unread message counts to be accurate, so that I know when there are new messages to read.

#### Acceptance Criteria

1. WHEN a Message is added to a Conversation, THE Chat_Module SHALL increment the unread counter belonging to the recipient.
2. WHEN a reader marks a Conversation as read, THE Chat_Module SHALL set that reader's unread counter to 0.
3. THE Admin_Dashboard_Module SHALL display the per-Conversation unread badge using the administrator's unread counter.

### Requirement 13: Design System and Branding

**User Story:** As the company, I want a consistent premium brand presentation, so that the app reflects the Keyframes identity.

#### Acceptance Criteria

1. THE Design_System SHALL apply the navy, golden amber, and white color palette using the defined color tokens across all screens.
2. THE Design_System SHALL apply the defined typography scale using Poppins for headings and brand text and Inter for body and UI text.
3. THE Design_System SHALL apply the defined spacing scale, corner-radius tokens, and elevation tokens to surfaces, cards, and modals.
4. THE Design_System SHALL render every interactive touch target at a minimum size of 48 by 48 logical pixels.
5. THE Design_System SHALL map each OrderStatus to its defined status color and label through the shared status chip widget.
6. WHERE a logo placeholder is required on the splash, auth header, app bars, or empty states, THE Design_System SHALL reference the supplied Keyframes logo asset.

### Requirement 14: Animation Strategy and Accessibility

**User Story:** As a user, I want smooth, tasteful animations that respect accessibility settings, so that the app feels fluid without causing discomfort.

#### Acceptance Criteria

1. WHEN navigating between screens, THE Animation_System SHALL apply shared-axis or fade-through route transitions.
2. WHEN dashboard KPI values are displayed, THE Animation_System SHALL animate the numeric values upward from 0.
3. WHERE featured carousel cards are displayed, THE Animation_System SHALL apply a 3D perspective tilt on drag or scroll.
4. WHILE the platform setting to disable animations is enabled, THE Animation_System SHALL disable non-essential motion.
5. THE Animation_System SHALL maintain animated regions at a target of 60 frames per second.

### Requirement 15: Service-Centric Marketplace Boundary

**User Story:** As the company, I want the app to remain service-centric, so that no per-employee hiring is ever exposed.

#### Acceptance Criteria

1. THE Keyframes_App SHALL present the catalog as ServiceListings only and SHALL NOT expose any per-employee selection or hiring surface in any route, screen, or model.
2. THE Keyframes_App SHALL associate every Order with a ServiceListing rather than with an individual employee.

### Requirement 16: Data Validation and Model Integrity

**User Story:** As a developer, I want all entities validated and serialized reliably, so that stored data stays consistent and round-trips correctly.

#### Acceptance Criteria

1. WHEN an AppUser is created or updated, THE Keyframes_App SHALL require a valid email format, a name of 2 to 60 characters, and, where a phone is present, 7 to 15 digits.
2. WHEN a ServiceListing is created or updated, THE Keyframes_App SHALL require a base price greater than or equal to 0, a title of 3 to 80 characters, and a ServiceCategory.
3. WHEN any entity is serialized to storage and read back, THE Keyframes_App SHALL reproduce an equivalent entity from the stored representation.
4. IF any free-text input contains unsafe content, THEN THE Keyframes_App SHALL sanitize the input before persistence.
5. IF an uploaded file violates the allowed file-type or size constraints, THEN THE Keyframes_App SHALL reject the upload.

### Requirement 17: Offline-First and Error Recovery

**User Story:** As a user, I want the app to behave gracefully when the network or a backend operation fails, so that I am not blocked or lose data.

#### Acceptance Criteria

1. WHILE no network connection is available, THE Keyframes_App SHALL display Cached_Catalog data together with an offline banner.
2. WHEN connectivity is regained, THE Keyframes_App SHALL automatically retry the failed catalog or chat fetch.
3. THE Keyframes_App SHALL wrap repository calls in a shared result pattern that renders loading, data, and error states uniformly.
4. IF a backend operation returns an error, THEN THE Keyframes_App SHALL surface the error state with a retry affordance and preserve any in-progress user input.
