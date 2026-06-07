# Keyframes — Mobile App

A premium Flutter app for **Keyframes**, a creative + IT services studio. It works like
Fiverr but is tailored for a small team: **no employee hiring**, just **pre-ordering**
service packages and a **direct chat** with the Keyframes team. Includes both a
**client experience** and an **admin console**.

> Brand: deep **dark blue** + **golden amber** + **white**.
> Typography: Poppins (headings) + Inter (body).
> Loaded with motion: a cinematic 3D logo preloader, animated backgrounds, and
> smooth screen transitions.

---

## Services covered
- Mobile app development
- Web development
- IoT projects
- University mini / major projects
- Graphic design (logos & brand identity, posters)
- Video editing (reels, promos)

---

## Features

### Client app
- **3D animated preloader** with the Keyframes logo (perspective flip-in, glow,
  depth-shadow layering, idle float).
- **Onboarding** carousel.
- **Login / Register** with an "Admin login" toggle (for the dashboard demo).
- **Home** — hero header, search, category grid, featured rail, popular services.
- **Services catalog** with category filters.
- **Service detail** with Basic / Standard / Premium packages.
- **Pre-order flow** — project brief, preferred contact, price summary, animated
  success confirmation. (No payment is taken — it reserves a slot.)
- **Orders** — active vs history, milestone progress tracker, order detail.
- **Chat** — thread list + real-time-style conversation (with simulated replies).
- **Profile** — grouped settings + logout.

### Admin console
- **Overview** dashboard — KPI cards (revenue, active, completed, total) + an
  animated weekly-revenue bar chart + recent orders.
- **Manage orders** — filter by status, update status from a bottom sheet.
- **Inbox** — client conversations (reuses the chat screen).
- Side **drawer** navigation.

---

## Getting started

```bash
# 1. Install Flutter (https://docs.flutter.dev/get-started/install)
flutter --version        # 3.22+ recommended

# 2. From the project folder:
cd keyframes_app
flutter pub get

# 3. Run on a device or emulator:
flutter run
```

### Demo logins
The email/password fields are pre-filled — just tap **Sign In**.
- **Client:** sign in with the Admin toggle **off**.
- **Admin console:** turn the **Admin login** switch **on**, then sign in.

---

## Using your real logo
The app currently draws the logo with a `CustomPainter` (so it runs with zero
assets). To use your exact brand file:

1. Add `assets/images/keyframes_logo.png` (transparent, ~1024×1024).
2. In `lib/widgets/brand_logo.dart`, pass `useImageAsset: true` (or flip the
   default), e.g. on the splash and headers.

A vector approximation already lives at `assets/images/keyframes_logo.svg`.

---

## Project structure

```
lib/
├── main.dart                     # entry point
├── app.dart                      # root flow: splash → onboarding → auth → shells
├── core/theme/                   # colors, typography, ThemeData
├── data/
│   ├── models/models.dart        # User, Service, Tier, Order, Chat models
│   └── mock_data.dart            # seed services / orders / chats
├── state/app_state.dart          # ChangeNotifier (auth, orders, chat)
├── widgets/                      # BrandLogo (3D), GlassCard, buttons, etc.
└── features/
    ├── splash/                   # 3D preloader
    ├── onboarding/
    ├── auth/
    ├── client/                   # home, services, detail, pre-order, orders, chat, profile
    └── admin/                    # dashboard, orders mgmt, inbox
```

---

## Backend: demo data or Firebase

The app ships with a clean **repository layer** (`lib/data/repositories/`) and a
**single switch** in `lib/core/app_config.dart`:

```dart
const bool kUseFirebase = false; // false = demo data, true = Firebase
```

- **`false` (default):** uses built-in demo data. No setup — perfect for previewing
  the UI. Login is simulated (any email/password works; toggle "Admin login" for
  the admin console).
- **`true`:** uses **Firebase Auth** (real accounts) and **Cloud Firestore**
  (real orders + chat that sync live across devices).

`AppState` talks only to the repositories, so flipping the switch changes the data
source without touching any UI code.

### Firebase setup (step by step)

1. **Create a Firebase project** at <https://console.firebase.google.com>.
2. **Enable Authentication** → Sign-in method → turn on **Email/Password**.
3. **Create a Cloud Firestore database** (start in *production* mode).
4. **Install the FlutterFire CLI** and link your project — this generates the real
   `lib/firebase_options.dart` and the native config files:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
5. **Turn the switch on:** set `kUseFirebase = true` in `lib/core/app_config.dart`.
6. `flutter pub get` then `flutter run`.

> Admin access: the in-app "Admin login" toggle is ignored in Firebase mode.
> A user becomes an admin when their `users/{uid}` document has `role: "admin"`.
> Set that field manually in the Firebase console for your own account.

### Firestore data model
```
users/{uid}        { name, email, role: "client"|"admin", avatarUrl }
orders/{orderId}   { serviceTitle, tierName, clientId, clientName, amount,
                     createdAt, dueDate, status, brief }
chats/{threadId}   { participants: [uid...], clientName, subtitle, online,
                     lastText, lastTime }
  messages/{msgId} { text, senderId, time, read }
```

### Required Firestore indexes
Two filtered+ordered queries need composite indexes. The first time you run them,
Firestore prints a console link that creates the index in one click. They are:
- `orders`: `clientId ==` + `createdAt desc`
- `chats`: `participants array-contains` + `lastTime desc`

### Starter security rules
Paste into **Firestore → Rules** (tighten further for production):
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isSignedIn() { return request.auth != null; }
    function isAdmin() {
      return isSignedIn() &&
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    match /users/{uid} {
      allow read: if isSignedIn();
      allow write: if request.auth.uid == uid;
    }

    match /orders/{orderId} {
      allow read: if isAdmin() || resource.data.clientId == request.auth.uid;
      allow create: if isSignedIn() && request.resource.data.clientId == request.auth.uid;
      allow update: if isAdmin() || resource.data.clientId == request.auth.uid;
    }

    match /chats/{threadId} {
      allow read, update: if isAdmin() || request.auth.uid in resource.data.participants;
      allow create: if isSignedIn();
      match /messages/{msgId} {
        allow read, create: if isSignedIn();
      }
    }
  }
}
```

---

## Notes
- Fonts load via `google_fonts` (downloaded at first run). To ship fully offline,
  bundle the TTFs and enable the `fonts:` block in `pubspec.yaml`.
- No paid/3rd-party chart library is used — the revenue chart is hand-drawn.
- The services **catalog** (categories, packages, prices) is defined in
  `lib/data/mock_data.dart`. Move it to Firestore too if you want to edit it
  without shipping an app update.
