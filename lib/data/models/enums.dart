/// Shared domain enumerations for the Keyframes app.
///
/// These enums are referenced across the presentation, domain, and data layers
/// (e.g. by the freezed models in `data/models/`, the order state machine, and
/// the router's role guard). They are defined exactly as specified in the
/// design document's "Data Models" section so that JSON serialization and
/// business logic agree on a single source of truth.
library;

/// The role of an [AppUser] within the system.
///
/// Clients browse the catalog and place pre-orders; admins manage orders,
/// conversations, and listings. Roles drive the router's role-based guards.
enum UserRole {
  /// A standard customer of the Keyframes marketplace.
  client,

  /// A Keyframes staff member with access to the admin dashboard.
  admin,
}

/// The high-level category a [ServiceListing] belongs to.
enum ServiceCategory {
  /// IT services (mobile/web/IoT development, university mini projects, etc.).
  itServices,

  /// Graphic-design services (video editing, posters, logo creation, etc.).
  graphicDesign,
}

/// The lifecycle status of an [Order].
///
/// The allowed transitions are
/// `pending -> inReview -> inProgress -> completed`, plus any non-`completed`
/// status -> `cancelled` (see the order state machine).
enum OrderStatus {
  /// A freshly created pre-order awaiting triage.
  pending,

  /// The order is being reviewed by the company.
  inReview,

  /// Work on the order is actively underway.
  inProgress,

  /// The order has been delivered/finished.
  completed,

  /// The order was cancelled before completion.
  cancelled,
}

/// The package tier selected for an [Order].
enum PackageTier {
  /// Entry-level package.
  basic,

  /// Mid-level package.
  standard,

  /// Top-level package.
  premium,
}

/// The kind of content carried by a chat [Message].
enum MessageType {
  /// A plain-text message (requires non-empty text).
  text,

  /// An image attachment (requires a media reference).
  image,

  /// A generic file attachment (requires a media reference).
  file,

  /// A system-generated message (e.g. status notifications).
  system,
}
