/// App-wide configuration flags.
///
/// ───────────────────────────────────────────────────────────────────────
///  THE ONE SWITCH:
///
///  • false  → the app uses built-in DEMO data (no setup needed). Great for
///             previewing the UI and for development.
///  • true   → the app uses FIREBASE for real login, orders and chat.
///             Requires a configured Firebase project (see README → "Firebase
///             setup"), i.e. a real lib/firebase_options.dart and the platform
///             config files (google-services.json / GoogleService-Info.plist).
/// ───────────────────────────────────────────────────────────────────────
const bool kUseFirebase = false;

/// Firestore collection names (kept in one place for consistency).
class FsCollections {
  FsCollections._();
  static const users = 'users';
  static const orders = 'orders';
  static const chats = 'chats';
  static const messages = 'messages'; // subcollection under each chat
}
