import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:json_annotation/json_annotation.dart';

import 'enums.dart';

part 'app_user.freezed.dart';
part 'app_user.g.dart';

/// An authenticated user of the Keyframes app.
///
/// A user always has a [role] (defaulting to [UserRole.client]); admins are
/// provisioned out-of-band and never self-register through the app.
@freezed
class AppUser with _$AppUser {
  const factory AppUser({
    required String id,
    required String name,
    required String email,
    String? phone,
    String? photoUrl,
    @Default(UserRole.client) UserRole role,
    required DateTime createdAt,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(json);
}
