/// Every route path and name the app has, declared in one place.
///
/// This is deliberately *not* the repo's usual "declare it next to the thing
/// it belongs to" shape (ADR-0018 D3): uniqueness is a property of the whole
/// *set*, not of any single member, so there has to be one place a test can
/// assert on. [allPaths] is what `test/core/router/app_router_test.dart`
/// checks — and it also checks that the real route table in `app_router.dart`
/// declares exactly these paths, so adding a route without a constant here
/// fails rather than quietly creating a second source of truth.
abstract final class AppRoutes {
  AppRoutes._();

  /// Cold-start location. Onboarding is still shown on every launch — the
  /// "don't show it twice" half is SCR-01 AC-3 and needs persistent storage
  /// the app does not have yet (ADR-0018 D7).
  static const String onboardingPath = '/';
  static const String onboardingName = 'onboarding';

  /// The post-onboarding destination. Still gated by the `AuthGate` *widget*
  /// rather than by a route-level `redirect` (ADR-0018 D4), so a signed-out
  /// visitor who reaches this path gets `LoginScreen` here — there is no
  /// separate `/login` path, and browsing posters without signing in is not
  /// open in this round even though the contract marks `/posters` public.
  static const String homePath = '/home';
  static const String homeName = 'home';

  static const String registerPath = '/register';
  static const String registerName = 'register';

  /// Carries nothing in the URL on purpose. `phoneNumber` is personal data
  /// and `verificationId`/`resendToken` are what Firebase uses to confirm a
  /// credential, so all three travel in `extra` instead (ADR-0018 D6) —
  /// `app_router_test.dart` asserts none of them ever reaches a path or a
  /// query string.
  static const String otpPath = '/otp';
  static const String otpName = 'otp';

  /// Name of the poster-detail path parameter, shared between the path
  /// pattern below and the router's `state.pathParameters` lookup so the two
  /// cannot drift.
  static const String posterIdParam = 'posterId';

  /// The poster UUID comes straight from the API and is already a public
  /// identifier, so it belongs in the path rather than in `extra`
  /// (ADR-0018 D6).
  static const String posterDetailPath = '/posters/:$posterIdParam';
  static const String posterDetailName = 'posterDetail';

  /// Builds the concrete location for [posterId], e.g. `/posters/<uuid>`.
  /// Call sites use this instead of interpolating a path themselves.
  static String posterDetail(String posterId) => '/posters/$posterId';

  /// Every path pattern above. Order is irrelevant; membership is not.
  static const List<String> allPaths = <String>[
    onboardingPath,
    homePath,
    registerPath,
    otpPath,
    posterDetailPath,
  ];

  /// Every route name above, paired 1:1 with [allPaths].
  static const List<String> allNames = <String>[
    onboardingName,
    homeName,
    registerName,
    otpName,
    posterDetailName,
  ];
}
