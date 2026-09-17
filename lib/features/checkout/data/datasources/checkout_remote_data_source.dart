import 'package:dio/dio.dart';

import '../../../../core/error/backend_envelope.dart';
import '../../../../core/error/debug_log.dart';
import '../../../../core/error/order_exception.dart';
import '../../../../core/utils/http_date.dart';
import '../models/order_model.dart';
import '../models/reservation_model.dart';
import '../models/shipping_address_model.dart';

/// Talks to `posternung-backend`'s reservation/order endpoints. Maps every
/// `DioException` to a domain `OrderException` so nothing above the
/// repository/datasource boundary depends on Dio — same convention as
/// `PosterRemoteDataSource`/`BackendAuthDataSource`.
abstract class CheckoutRemoteDataSource {
  /// `POST /listings/{poster_id}/reserve`. **No request body** — the buyer
  /// comes from the Bearer token and the clock from the server
  /// (`ADR-0037` — see the contract's own description of this endpoint).
  Future<ReservationModel> reserveListing(String posterId);

  /// `POST /orders`.
  Future<OrderModel> createOrder({
    required String reservationId,
    required ShippingAddressModel shippingAddress,
  });
}

class CheckoutRemoteDataSourceImpl implements CheckoutRemoteDataSource {
  CheckoutRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  static const _orders = '/api/v1/orders';

  static const _dateHeader = 'date';

  static String _reservePath(String posterId) =>
      '/api/v1/listings/$posterId/reserve';

  @override
  Future<ReservationModel> reserveListing(String posterId) => _guard(() async {
    // Deliberately no `data:` argument — the contract forbids a body on
    // this endpoint (security-baseline §4: never trust a client-asserted
    // buyer/clock). `_dio.post` defaults `data` to `null`, which is what
    // the datasource test verifies was actually sent.
    final response = await _dio.post<Map<String, dynamic>>(
      _reservePath(posterId),
    );
    // The `Date` header is the server's own clock at the instant it
    // answered — kept on the DTO so the countdown can anchor a **200**
    // replay (A5-D1) on "now" rather than on the row's original
    // `created_at` (code-critic 2026-09-17, F-Med). `null` when missing or
    // unparseable; the entity falls back to `createdAt` in that case, so a
    // bad header degrades to the pre-A5 behaviour instead of failing the
    // reserve. Dio lower-cases header names; `headers[...]` (not
    // `headers.value(...)`) so a pathological duplicate `Date` can't throw
    // either.
    return ReservationModel.fromJson(response.data!).copyWith(
      serverReceivedAt: tryParseHttpDate(
        response.headers[_dateHeader]?.firstOrNull,
      ),
    );
  });

  @override
  Future<OrderModel> createOrder({
    required String reservationId,
    required ShippingAddressModel shippingAddress,
  }) => _guard(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      _orders,
      data: {
        'reservation_id': reservationId,
        'shipping_address': shippingAddress.toJson(),
      },
    );
    return OrderModel.fromJson(response.data!);
  });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      // Same envelope contract as every other backend-facing datasource
      // (ADR-0017 D2, Amendment 1 A1-D1) — `OrderException.fromEnvelope` is
      // the only place able to populate `displayMessage` and the typed
      // `reservedUntil`/`expiredAt`/`limit`/`retryAfter` fields (Amendment 2
      // A2-D2).
      final envelope = backendErrorEnvelopeOf(e);
      if (envelope != null) {
        throw OrderException.fromEnvelope(
          envelope,
          debugDetail: logDebugDetail(
            envelope.details,
            source: 'checkout_remote_envelope',
          ),
        );
      }

      // No structured envelope (connection failure, gateway/non-JSON 5xx,
      // …) → a stable code; the presentation-layer table maps it to Thai
      // (`checkout_error_display.dart`).
      final status = e.response?.statusCode;
      if (status == null) {
        throw const OrderException(code: 'network_error');
      }
      if (status >= 500) {
        throw const OrderException(code: 'server_error');
      }
      throw const OrderException(code: 'unknown_error');
    } on OrderException {
      rethrow;
    } catch (e) {
      // Anything besides DioException — a malformed success response that
      // OrderModel.fromJson/toEntity can't parse, etc. — must not escape
      // this datasource as a bare object with no `code` to display. `code`
      // is fixed, never composed from `e.runtimeType` (ADR-0017 D6).
      throw OrderException(
        code: 'checkout_remote_guard_unexpected',
        debugDetail: logDebugDetail(
          e.toString(),
          source: 'checkout_remote_guard',
        ),
      );
    }
  }
}
