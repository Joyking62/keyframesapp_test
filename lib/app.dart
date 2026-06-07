import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/admin/admin_shell.dart';
import 'features/auth/auth_screen.dart';
import 'features/client/client_shell.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/splash/splash_screen.dart';
import 'state/app_state.dart';

class KeyframesApp extends StatelessWidget {
  const KeyframesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'Keyframes',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const _RootFlow(),
      ),
    );
  }
}

/// Drives the top-level navigation:
/// splash → onboarding → auth → (admin | client) shells.
class _RootFlow extends StatefulWidget {
  const _RootFlow();

  @override
  State<_RootFlow> createState() => _RootFlowState();
}

class _RootFlowState extends State<_RootFlow> {
  bool _splashDone = false;
  bool _onboardingDone = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    final Widget current;
    if (!_splashDone) {
      current = SplashScreen(
        key: const ValueKey('splash'),
        onFinish: () => setState(() => _splashDone = true),
      );
    } else if (!_onboardingDone) {
      current = OnboardingScreen(
        key: const ValueKey('onboarding'),
        onDone: () => setState(() => _onboardingDone = true),
      );
    } else if (!app.isLoggedIn) {
      current = const AuthScreen(key: ValueKey('auth'));
    } else if (app.isAdmin) {
      current = const AdminShell(key: ValueKey('admin'));
    } else {
      current = const ClientShell(key: ValueKey('client'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      child: current,
    );
  }
}
