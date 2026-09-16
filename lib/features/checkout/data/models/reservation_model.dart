import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/reservation.dart';

part 'reservation_model.freezed.dart';
part 'reservation_model.g.dart';

/// DTO for the backend's `ReservationResponse`
/// (`POST /listings/{poster_id}/reserve`). Carries `user_id`/`status` even
/// though [toEntity] drops both — kept on the DTO so a future caller that
/// does need them (e.g. a reservation-status screen) doesn't have to touch
/// the wire-parsing layer again.
@freezed
abstract class ReservationModel with _$ReservationModel {
  const ReservationModel._();

  const factory ReservationModel({
    required String id,
    @JsonKey(name: 'poster_id') required String posterId,
    @JsonKey(name: 'user_id') required String userId,
    required String status,
    @JsonKey(name: 'expires_at') required DateTime expiresAt,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _ReservationModel;

  factory ReservationModel.fromJson(Map<String, dynamic> json) =>
      _$ReservationModelFromJson(json);

  Reservation toEntity() => Reservation(
    id: id,
    posterId: posterId,
    expiresAt: expiresAt,
    createdAt: createdAt,
  );
}
