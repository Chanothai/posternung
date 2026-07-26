import '../../domain/entities/auth_user.dart';

/// DTO for the backend's `UserResponse` (from `GET /auth/me`). Carries more
/// than the domain [AuthUser] needs today (`phone`, `is_verified`,
/// `created_at`); [toEntity] narrows it to what the app consumes.
class BackendUser {
  const BackendUser({
    required this.id,
    required this.email,
    this.phone,
    required this.isVerified,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String? phone;
  final bool isVerified;
  final DateTime createdAt;

  factory BackendUser.fromJson(Map<String, dynamic> json) => BackendUser(
    id: json['id'] as String,
    email: json['email'] as String,
    phone: json['phone'] as String?,
    isVerified: json['is_verified'] as bool,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  AuthUser toEntity() => AuthUser(uid: id, email: email);
}
