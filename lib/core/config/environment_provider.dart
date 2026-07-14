import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'environment.dart';

/// Overridden in `main.dart` with the already-resolved [Environment] so
/// there is a single source of truth instead of re-resolving it here.
final environmentProvider = Provider<Environment>(
  (ref) => throw UnimplementedError(
    'environmentProvider must be overridden in main.dart',
  ),
);
