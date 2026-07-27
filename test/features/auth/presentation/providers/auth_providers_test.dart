import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posternung/core/network/token_storage.dart';
import 'package:posternung/features/auth/data/datasources/backend_auth_data_source.dart';
import 'package:posternung/features/auth/domain/repositories/auth_repository.dart';
import 'package:posternung/features/auth/presentation/providers/auth_providers.dart';
import 'package:posternung/features/auth/presentation/providers/backend_session_provider.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockTokenStorage extends Mock implements TokenStorage {}

class MockBackendAuthDataSource extends Mock implements BackendAuthDataSource {}

void main() {
  late MockAuthRepository authRepository;
  late MockTokenStorage storage;
  late MockBackendAuthDataSource backend;

  setUp(() {
    authRepository = MockAuthRepository();
    storage = MockTokenStorage();
    backend = MockBackendAuthDataSource();
    when(() => storage.readAccessToken()).thenAnswer((_) async => null);
    // No refresh token stored — these tests are about the Firebase-throws-
    // in-`finally` ordering, not the revoke call; that's covered in
    // backend_session_provider_test.dart's `signOut` group.
    when(() => storage.readRefreshToken()).thenAnswer((_) async => null);
    when(() => storage.clear()).thenAnswer((_) async {});
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        tokenStorageProvider.overrideWithValue(storage),
        backendAuthDataSourceProvider.overrideWithValue(backend),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('signOut', () {
    test(
      'clears the backend session when Firebase sign-out succeeds',
      () async {
        when(() => authRepository.signOut()).thenAnswer((_) async {});

        final container = makeContainer();
        await container.read(backendSessionProvider.future);
        await container.read(authViewModelProvider.notifier).signOut();

        verify(() => storage.clear()).called(1);
        expect(container.read(authViewModelProvider).hasError, isFalse);
      },
    );

    test('still clears the backend session when Firebase sign-out throws, '
        'and surfaces the original error — regression for the ordering bug '
        'where a failed Firebase sign-out left backend JWTs on disk', () async {
      final firebaseError = Exception('firebase unreachable');
      when(() => authRepository.signOut()).thenThrow(firebaseError);

      final container = makeContainer();
      await container.read(backendSessionProvider.future);
      await container.read(authViewModelProvider.notifier).signOut();

      // The backend session must still have been cleared even though the
      // Firebase call failed first.
      verify(() => storage.clear()).called(1);
      expect(container.read(backendSessionProvider).value, isNull);
      // And the original Firebase failure is still what the UI sees.
      final state = container.read(authViewModelProvider);
      expect(state.hasError, isTrue);
      expect(state.error, firebaseError);
    });
  });
}
