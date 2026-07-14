import 'package:flutter/services.dart' show appFlavor;

enum Environment { sit, uat, production }

extension EnvironmentX on Environment {
  String get label => switch (this) {
    Environment.sit => 'SIT',
    Environment.uat => 'UAT',
    Environment.production => 'Production',
  };
}

/// Resolves the running environment from the native `--flavor` value
/// (`appFlavor`, populated by `flutter run/build --flavor <x>` on
/// Android/iOS). Web has no native flavor mechanism, so it falls back to
/// `--dart-define=ENVIRONMENT=...`, defaulting to [Environment.sit] rather
/// than silently defaulting an unconfigured build to production.
Environment resolveEnvironment({String? flavorOverride}) {
  const webFallback = String.fromEnvironment('ENVIRONMENT');
  final flavor =
      flavorOverride ?? appFlavor ?? (webFallback.isEmpty ? null : webFallback);
  return switch (flavor) {
    'production' => Environment.production,
    'uat' => Environment.uat,
    _ => Environment.sit,
  };
}
