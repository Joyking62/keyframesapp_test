import 'package:freezed_annotation/freezed_annotation.dart';

import 'app_user.dart';

part 'bootstrap_result.freezed.dart';

/// Pure decision data produced by `bootstrap()` after the splash completes.
///
/// Contains no navigation side effects; `resolveInitialRoute` consumes this to
/// decide the initial route (onboarding / login / client home / admin orders).
@freezed
class BootstrapResult with _$BootstrapResult {
  const factory BootstrapResult({
    /// Whether the user has previously completed onboarding.
    @Default(false) bool seenOnboarding,

    /// The currently authenticated user, or null if signed out.
    AppUser? user,
  }) = _BootstrapResult;
}
