import '../../../../core/error/debug_log.dart';
import '../../../../core/error/order_exception.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/reservation.dart';
import '../../domain/entities/shipping_address.dart';
import '../../domain/repositories/checkout_repository.dart';
import '../datasources/checkout_remote_data_source.dart';
import '../models/shipping_address_model.dart';

class CheckoutRepositoryImpl implements CheckoutRepository {
  CheckoutRepositoryImpl(this._remoteDataSource);

  final CheckoutRemoteDataSource _remoteDataSource;

  @override
  Future<Reservation> reserveListing(String posterId) async {
    try {
      final model = await _remoteDataSource.reserveListing(posterId);
      return model.toEntity();
    } on OrderException {
      rethrow;
    } catch (e) {
      // `code` is fixed, never composed from `e.runtimeType` (ADR-0017 D6).
      throw OrderException(
        code: 'checkout_repo_reserve_unexpected',
        debugDetail: logDebugDetail(
          e.toString(),
          source: 'checkout_repo_reserve',
        ),
      );
    }
  }

  @override
  Future<Order> createOrder({
    required String reservationId,
    required ShippingAddress shippingAddress,
  }) async {
    try {
      final model = await _remoteDataSource.createOrder(
        reservationId: reservationId,
        shippingAddress: ShippingAddressModel.fromEntity(shippingAddress),
      );
      return model.toEntity();
    } on OrderException {
      rethrow;
    } catch (e) {
      throw OrderException(
        code: 'checkout_repo_create_order_unexpected',
        debugDetail: logDebugDetail(
          e.toString(),
          source: 'checkout_repo_create_order',
        ),
      );
    }
  }
}
