import 'package:freezed_annotation/freezed_annotation.dart';

part 'register_input.freezed.dart';

/// Immutable input value object for [AuthRepository.register].
///
/// Collects the fields gathered on the registration form. Role is always
/// resolved to `client` server-side; no role selector is ever exposed.
@freezed
class RegisterInput with _$RegisterInput {
  const factory RegisterInput({
    /// Full name (validated 2-60 chars by the auth layer).
    required String name,

    /// Email address (validated against the email regex).
    required String email,

    /// Phone number (validated 7-15 digits).
    required String phone,

    /// Plaintext password forwarded to the auth backend.
    required String password,
  }) = _RegisterInput;
}
