import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posternung/core/diagnostics/startup_trace.dart';
import 'package:posternung/core/error/auth_exception.dart';
import 'package:posternung/core/router/app_router.dart';
import 'package:posternung/core/router/app_routes.dart';
import 'package:posternung/features/auth/domain/entities/auth_user.dart';
import 'package:posternung/features/auth/presentation/providers/auth_providers.dart';
import 'package:posternung/features/auth/presentation/providers/backend_session_provider.dart';
import 'package:posternung/features/auth/presentation/providers/session_provider.dart';
import 'package:posternung/features/poster/domain/entities/paginated_posters.dart';
import 'package:posternung/features/poster/domain/repositories/poster_repository.dart';
import 'package:posternung/features/poster/presentation/providers/poster_providers.dart';
import 'package:posternung/features/onboarding/presentation/onboarding_entry_gate.dart';

import '../../support/router_harness.dart';

/// INF-40 step 1 — `docs/status/gates/INF-40-gate1.md` (workspace repo).
///
/// A companion to `onboarding_session_entry_test.dart` (which this file must
/// not modify — see the ticket's scope note) that proves the *wiring*, not
/// just the formatter: that `OnboardingEntryGate`'s four real decision paths
/// each call `StartupTrace.gateDecision` with the `via` the gate plan names
/// for that path, not merely that `StartupTrace` itself formats a line
/// correctly in isolation (`test/core/diagnostics/startup_trace_test.dart`
/// covers that half — this file is the other half `test-quality` §3.1 warns
/// a formatter-only test can never reach, since a formatter test only ever
/// asserts on values the test itself chose to pass in).
///
/// Reuses the exact fakes/harness shape `onboarding_session_entry_test.dart`
/// established (`_FakeBackendSession` overriding `backendSessionProvider`,
/// `routedApp` over the real route table) rather than inventing a new one —
/// duplicated here, not imported, since the originals are file-private.
void main() {
  const AuthUser signedIn = AuthUser(uid: 'u1', email: 'a@b.co');

  late _MockPosterRepository repository;

  setUp(() {
    repository = _MockPosterRepository();
    when(
      () => repository.listPosters(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer(
      (_) async =>
          const PaginatedPosters(items: [], total: 0, limit: 20, offset: 0),
    );
    StartupTrace.debugEnabledOverride = true;
  });

  tearDown(StartupTrace.debugReset);

  // Return type left to inference: Riverpod 3 does not export `Override`
  // (same note as `onboarding_session_entry_test.dart`'s own helper).
  overrides(Future<AuthUser?> Function() session) => [
    backendSessionProvider.overrideWith(() => _FakeBackendSession(session)),
    authViewModelProvider.overrideWith(_NoopAuthViewModel.new),
    posterRepositoryProvider.overrideWithValue(repository),
  ];

  Future<List<String>> coldStart(
    WidgetTester tester,
    Future<AuthUser?> Function() session,
  ) async {
    final lines = <String>[];
    StartupTrace.debugSink = lines.add;
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(session),
        child: routedApp(location: AppRoutes.onboardingPath, routes: appRoutes),
      ),
    );
    return lines;
  }

  testWidgets(
    'a restored session traces gate_decision dest=home via=data_user, then '
    'gate_go_home mounted=true — the path BL-127/BL-130 are both about',
    (WidgetTester tester) async {
      final lines = await coldStart(tester, () async => signedIn);
      await tester.pumpAndSettle();

      expect(lines.first, matches(RegExp(r'^t=\d+ event=gate_init$')));
      expect(
        lines,
        anyElement(
          matches(RegExp(r'event=gate_decision dest=home via=data_user$')),
        ),
        reason:
            'signed-in cold start must classify via=data_user, not any other via',
      );
      expect(
        lines,
        anyElement(matches(RegExp(r'event=gate_go_home mounted=true$'))),
      );
      expect(
        lines.any((l) => l.contains('via=deadline')),
        isFalse,
        reason:
            'the session resolved well inside the 2s deadline — no deadline path',
      );
    },
  );

  testWidgets(
    'no stored session traces gate_decision dest=onboarding via=data_null',
    (WidgetTester tester) async {
      final lines = await coldStart(tester, () async => null);
      await tester.pump();
      await tester.pump();

      expect(
        lines,
        anyElement(
          matches(
            RegExp(r'event=gate_decision dest=onboarding via=data_null$'),
          ),
        ),
      );
      expect(lines.any((l) => l.contains('via=data_user')), isFalse);
      expect(lines.any((l) => l.contains('via=deadline')), isFalse);
      expect(
        lines.any((l) => l.contains('via=session_expiry')),
        isFalse,
        reason:
            'no StartupTrace.sessionExpiryFired() happened in this process — '
            'the correlation in StartupTrace.gateDecision must not upgrade '
            'data_null on its own',
      );
      expect(lines.any((l) => l.contains('via=session_error')), isFalse);
    },
  );

  testWidgets(
    'a session still undecided at the 2s deadline traces deadline_fired '
    'mounted=true and gate_decision dest=onboarding via=deadline',
    (WidgetTester tester) async {
      final undecided = Completer<AuthUser?>();
      final lines = await coldStart(tester, () => undecided.future);

      await tester.pump(const Duration(milliseconds: 1900));
      expect(
        lines.any((l) => l.contains('event=gate_decision')),
        isFalse,
        reason: 'no decision yet — still short of the deadline',
      );

      await tester.pump(const Duration(milliseconds: 200));

      expect(
        lines,
        anyElement(matches(RegExp(r'event=deadline_fired mounted=true$'))),
      );
      expect(
        lines,
        anyElement(
          matches(RegExp(r'event=gate_decision dest=onboarding via=deadline$')),
        ),
      );
    },
  );

  testWidgets(
    'INF-40 AC-2 — the gate disarms its deadline at the moment it sends a '
    'signed-in reader to /home, so it cannot decide a second time',
    (WidgetTester tester) async {
      final lines = await coldStart(tester, () async => signedIn);
      // One frame for the session to resolve and the data branch to build.
      // Its post-frame callback runs at the end of this same frame — that is
      // where both the trace line and the cancel happen.
      await tester.pump();

      // Sanity first: this run really did take the go-home path, so the
      // assertion below is about a decision that happened — not about a gate
      // that quietly never decided anything.
      expect(
        lines,
        anyElement(matches(RegExp(r'event=gate_go_home mounted=true$'))),
        reason: 'the go-home path must have run for this test to mean anything',
      );

      // 🔴 Read the invariant here and only here. The gate is still mounted
      // for this instant; by the time the route transition finishes it is
      // gone, `dispose()` has cancelled the timer for its own reasons, and
      // every observable difference between fixed and broken has vanished.
      final OnboardingEntryGateState gate = tester
          .state<OnboardingEntryGateState>(find.byType(OnboardingEntryGate));
      expect(
        gate.debugDeadlineIsActive,
        isFalse,
        reason:
            'the deadline must be cancelled at the decision point. Left armed '
            'it fires ~2s later and flips _stoppedWaiting, and build() then '
            'returns OnboardingPageViewScreen on top of a reader already at '
            '/home — measured at t=2001 with mounted=true on a real device, '
            'on every signed-in cold start (BL-130)',
      );

      expect(
        lines.where((String l) => l.contains('event=gate_decision')).length,
        1,
        reason: 'one cold start, one decision',
      );
    },
  );

  testWidgets(
    'a terminally-failed session traces gate_decision dest=onboarding '
    'via=session_error, not via=session_expiry (round 2 correction — see '
    'StartupTrace\'s GateDecisionVia doc comment: round 1 had this backwards)',
    (WidgetTester tester) async {
      final lines = <String>[];
      StartupTrace.debugSink = lines.add;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWithValue(
              AsyncError<AuthUser?>(
                const AuthException(code: 'network_error'),
                StackTrace.current,
              ),
            ),
            authViewModelProvider.overrideWith(_NoopAuthViewModel.new),
            posterRepositoryProvider.overrideWithValue(repository),
          ],
          child: routedApp(
            location: AppRoutes.onboardingPath,
            routes: appRoutes,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        lines,
        anyElement(
          matches(
            RegExp(r'event=gate_decision dest=onboarding via=session_error$'),
          ),
        ),
      );
    },
  );
}

class _MockPosterRepository extends Mock implements PosterRepository {}

class _NoopAuthViewModel extends AuthViewModel {
  @override
  FutureOr<void> build() {}
}

class _FakeBackendSession extends BackendSessionNotifier {
  _FakeBackendSession(this._restore);

  final Future<AuthUser?> Function() _restore;

  @override
  Future<AuthUser?> build() => _restore();
}
