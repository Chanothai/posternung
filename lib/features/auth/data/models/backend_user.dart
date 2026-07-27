import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/auth_user.dart';

part 'backend_user.freezed.dart';
part 'backend_user.g.dart';

/// DTO for the backend's `UserResponse` (from `GET /auth/me`). Carries more
/// than the domain [AuthUser] needs today (`phone`, `is_verified`,
/// `created_at`); [toEntity] narrows it to what the app consumes.
@freezed
abstract class BackendUser with _$BackendUser {
  const BackendUser._();

  const factory BackendUser({
    required String id,
    // Nullable — matches the backend's `UserResponse.email` (`anyOf: [string,
    // null]`), which is genuinely null for a phone-only signup (no email
    // claim on the Firebase token). Declaring this `required String` used to
    // crash `fromJson` with a bare `TypeError` the moment a phone-only user
    // hit `GET /auth/me` — see `AuthUser.email`, which was already nullable
    // for exactly this reason.
    String? email,
    String? phone,
    @JsonKey(name: 'is_verified') required bool isVerified,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _BackendUser;

  factory BackendUser.fromJson(Map<String, dynamic> json) =>
      _$BackendUserFromJson(json);

  AuthUser toEntity() => AuthUser(uid: id, email: email);
}
