import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'motion.dart';

/// The axis along which a shared-axis transition moves its content.
enum SharedAxisDirection {
  /// Slide along the X axis (typical for forward/back peer navigation).
  horizontal,

  /// Slide along the Y axis (typical for vertical step navigation).
  vertical,

  /// Scale on the Z axis (typical for parent/child drill-down navigation).
  scaled,
}

/// Linear interpolation helper kept local so this file stays dependency-light.
double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Builds a go_router [CustomTransitionPage] that animates with a Material
/// **shared-axis** transition (combined slide + fade, with the outgoing route
/// moving in the opposite direction).
///
/// Use directly from a `GoRoute.pageBuilder`:
///
/// ```dart
/// GoRoute(
///   path: '/detail',
///   pageBuilder: (context, state) => buildSharedAxisPage<void>(
///     key: state.pageKey,
///     child: const ServiceDetailScreen(),
///   ),
/// );
/// ```
///
/// Requirements: 14.1, 14.4.
CustomTransitionPage<T> buildSharedAxisPage<T>({
  required Widget child,
  SharedAxisDirection direction = SharedAxisDirection.horizontal,
  LocalKey? key,
  String? name,
  Object? arguments,
  String? restorationId,
  Duration duration = KMotion.medium,
  bool fullscreenDialog = false,
  bool maintainState = true,
}) {
  return CustomTransitionPage<T>(
    key: key,
    name: name,
    arguments: arguments,
    restorationId: restorationId,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    fullscreenDialog: fullscreenDialog,
    maintainState: maintainState,
    child: child,
    transitionsBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    ) {
      if (KMotion.isDisabled(context)) {
        return child;
      }
      return _SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        direction: direction,
        child: child,
      );
    },
  );
}

/// Builds a go_router [CustomTransitionPage] that animates with a Material
/// **fade-through** transition (outgoing fades out, incoming fades in while
/// gently scaling up). Best for switching between unrelated top-level
/// destinations such as bottom-navigation tabs.
///
/// Requirements: 14.1, 14.4.
CustomTransitionPage<T> buildFadeThroughPage<T>({
  required Widget child,
  LocalKey? key,
  String? name,
  Object? arguments,
  String? restorationId,
  Duration duration = KMotion.medium,
  bool fullscreenDialog = false,
  bool maintainState = true,
}) {
  return CustomTransitionPage<T>(
    key: key,
    name: name,
    arguments: arguments,
    restorationId: restorationId,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    fullscreenDialog: fullscreenDialog,
    maintainState: maintainState,
    child: child,
    transitionsBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    ) {
      if (KMotion.isDisabled(context)) {
        return child;
      }
      return _FadeThroughTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        child: child,
      );
    },
  );
}

/// Combined slide + fade transition for the incoming route, with the outgoing
/// route sliding the opposite way and fading out.
class _SharedAxisTransition extends StatelessWidget {
  const _SharedAxisTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.direction,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final SharedAxisDirection direction;
  final Widget child;

  /// Slide distance in logical pixels for horizontal/vertical axes.
  static const double _distance = 30.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[animation, secondaryAnimation]),
      builder: (BuildContext context, Widget? _) {
        final double enter = KMotion.enter.transform(animation.value);
        final double leave = KMotion.exit.transform(secondaryAnimation.value);

        // Incoming fades in; while later covered by a new route it fades out.
        final double opacity =
            (animation.value * (1.0 - secondaryAnimation.value)).clamp(0.0, 1.0);

        double dx = 0.0;
        double dy = 0.0;
        double scale = 1.0;
        switch (direction) {
          case SharedAxisDirection.horizontal:
            dx = _distance * (1.0 - enter) - _distance * leave;
          case SharedAxisDirection.vertical:
            dy = _distance * (1.0 - enter) - _distance * leave;
          case SharedAxisDirection.scaled:
            scale = _lerp(0.92, 1.0, enter) * _lerp(1.0, 1.06, leave);
        }

        Widget content = child;
        if (scale != 1.0) {
          content = Transform.scale(scale: scale, child: content);
        }
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: content,
          ),
        );
      },
    );
  }
}

/// Cross-fade between routes where the incoming content also scales up slightly.
class _FadeThroughTransition extends StatelessWidget {
  const _FadeThroughTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[animation, secondaryAnimation]),
      builder: (BuildContext context, Widget? _) {
        // Incoming content fades in over the second half of the transition to
        // avoid overlapping with the outgoing route's fade out.
        final double fadeIn = Curves.easeOut.transform(
          ((animation.value - 0.3) / 0.7).clamp(0.0, 1.0),
        );
        final double fadeOut = 1.0 - secondaryAnimation.value;
        final double opacity = (fadeIn * fadeOut).clamp(0.0, 1.0);
        final double scale = _lerp(0.92, 1.0, KMotion.enter.transform(animation.value));

        return Opacity(
          opacity: opacity,
          child: Transform.scale(scale: scale, child: child),
        );
      },
    );
  }
}
