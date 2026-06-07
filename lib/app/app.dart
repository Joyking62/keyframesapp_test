import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keyframes_app/app/router.dart';
import 'package:keyframes_app/core/theme/app_theme.dart';

/// Root widget of the Keyframes application (Requirement 13.1).
///
/// A [ConsumerWidget] that builds a [MaterialApp.router], injecting:
/// * the global brand theme from [buildKeyframesTheme] (navy/amber/white
///   design system), and
/// * the go_router configuration from [routerProvider], which owns the route
///   table, the bottom-navigation shells, and the role-based redirect guards.
///
/// Keeping the router behind a provider lets the entire navigation graph be
/// composed against the same [ProviderScope] (and overridden wholesale in
/// tests) without this widget knowing anything about route construction.
class KeyframesApp extends ConsumerWidget {
  const KeyframesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Keyframes',
      debugShowCheckedModeBanner: false,
      theme: buildKeyframesTheme(),
      routerConfig: router,
    );
  }
}
