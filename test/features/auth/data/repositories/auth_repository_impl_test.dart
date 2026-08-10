import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posternung/core/error/auth_exception.dart';
import 'package:posternung/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:posternung/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:posternung/features/auth/domain/entities/auth_user.dart';

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

void main() {
  late MockAuthRemoteDataSource dataSource;
  late AuthRepositoryImpl repository;

  setUp(() {
    dataSource = MockAuthRemoteDataSource();
    repository = AuthRepositoryImpl(dataSource);
  });

  group('signOut', () {
    test('calls dataSource.signOut', () async {
      when(() => dataSource.signOut()).thenAnswer((_) async {});

      await repository.signOut();

      verify(() => dataSource.signOut()).called(1);
    });

    test('maps a FirebaseAuthException into an AuthException with the same '
        'code, and the SDK message only as debugDetail (ADR-0017 D2 — never '
        'displayMessage)', () async {
      when(() => dataSource.signOut()).thenThrow(
        FirebaseAuthException(
          code: 'network-request-failed',
          message: 'no network',
        ),
      );

      expect(
        () => repository.signOut(),
        throwsA(
          isA<AuthException>()
              .having((e) => e.code, 'code', 'network-request-failed')
              .having((e) => e.debugDetail, 'debugDetail', 'no network')
              .having((e) => e.displayMessage, 'displayMessage', isNull),
        ),
      );
    });

    test('a non-FirebaseAuthException failure still reaches the caller as an '
        'AuthException with a fixed code', () async {
      when(() => dataSource.signOut()).thenThrow(Exception('boom'));

      expect(
        () => repository.signOut(),
        throwsA(isA<AuthException>().having((e) => e.code, 'code', 'unknown')),
      );
    });
  });

  group('authStateChanges', () {
    test('maps a non-null Firebase user to AuthUser', () async {
      final user = _MockUser();
      when(() => user.uid).thenReturn('uid-1');
      when(() => user.email).thenReturn('user@example.com');
      when(
        () => dataSource.authStateChanges,
      ).thenAnswer((_) => Stream<User?>.value(user));

      final result = await repository.authStateChanges.first;

      expect(result, const AuthUser(uid: 'uid-1', email: 'user@example.com'));
    });

    test('maps a null Firebase user (signed out) to null', () async {
      when(
        () => dataSource.authStateChanges,
      ).thenAnswer((_) => Stream<User?>.value(null));

      final result = await repository.authStateChanges.first;

      expect(result, isNull);
    });
  });
}

class _MockUser extends Mock implements User {}
