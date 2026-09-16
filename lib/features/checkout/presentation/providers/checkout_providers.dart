import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../data/datasources/checkout_remote_data_source.dart';
import '../../data/repositories/checkout_repository_impl.dart';
import '../../domain/repositories/checkout_repository.dart';
import '../../domain/usecases/create_order.dart';
import '../../domain/usecases/reserve_listing.dart';

/// DI chain for the checkout feature — datasource → repository → usecases,
/// same shape as `poster_providers.dart`. The ViewModel provider lives in
/// `checkout_view_model.dart`, and the transient-flow/countdown providers in
/// their own files, per this feature's own `CLAUDE.md`.
final Provider<CheckoutRemoteDataSource> checkoutRemoteDataSourceProvider =
    Provider<CheckoutRemoteDataSource>(
      (ref) => CheckoutRemoteDataSourceImpl(ref.watch(dioProvider)),
    );

final Provider<CheckoutRepository> checkoutRepositoryProvider =
    Provider<CheckoutRepository>(
      (ref) =>
          CheckoutRepositoryImpl(ref.watch(checkoutRemoteDataSourceProvider)),
    );

/// Called from `ReserveListingViewModel.reserve()`
/// (`reserve_listing_view_model.dart`), which backs the "ซื้อเลย" button on
/// `PosterDetailScreen` (SCR-07 B3).
final Provider<ReserveListing> reserveListingProvider =
    Provider<ReserveListing>(
      (ref) => ReserveListing(ref.watch(checkoutRepositoryProvider)),
    );

final Provider<CreateOrder> createOrderProvider = Provider<CreateOrder>(
  (ref) => CreateOrder(ref.watch(checkoutRepositoryProvider)),
);
