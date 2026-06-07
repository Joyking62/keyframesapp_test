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

## Wiring a real backend
The app is intentionally backend-agnostic. `AppState` is the single integration
point — replace the mocked methods with your provider of choice:

- **Auth** → Firebase Auth / your API in `login`, `register`, `logout`.
- **Orders** → Firestore / REST in `placePreOrder`, `updateOrderStatus`.
- **Chat** → Firestore streams / WebSocket in `sendMessage` + thread loading.
- Swap `MockData` seeds for live queries.

---

## Notes
- Fonts load via `google_fonts` (downloaded at first run). To ship fully offline,
  bundle the TTFs and enable the `fonts:` block in `pubspec.yaml`.
- No paid/3rd-party chart library is used — the revenue chart is hand-drawn.
