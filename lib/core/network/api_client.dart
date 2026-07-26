import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../config/api_base_url_resolver.dart';
import '../config/environment_provider.dart';

/// Shared `posternung-backend` HTTP client, base URL resolved per
/// [Environment] via [apiBaseUrlFor].
///
/// In debug builds only, a [PrettyDioLogger] prints each request/response to
/// the run console — stripped from every release build (SIT/UAT/production).
final dioProvider = Provider<Dio>((ref) {
  final environment = ref.watch(environmentProvider);
  final dio = Dio(BaseOptions(baseUrl: apiBaseUrlFor(environment)));

  if (kDebugMode) {
    // `requestHeader: true` prints the `Authorization: Bearer …` header — fine
    // for the debug console (never ships in release); set it false if you'd
    // rather keep the access token out of dev logs.
    dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        error: true,
        compact: true,
      ),
    );
  }

  return dio;
});
