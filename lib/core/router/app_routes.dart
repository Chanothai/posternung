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

  /// Cold-start location. What it builds is `OnboardingEntryGate`, which
  /// decides from the session whether the intro is shown at all — the
  /// reasoning, the branches and the deadline all live on that class.
  ///
  /// Recorded here only because this file used to say the opposite: the old
  /// comment called SCR-01 AC-3 blocked on "persistent storage the app does
  /// not have yet (ADR-0018 D7)", and `flutter_secure_storage` had been in
  /// `pubspec.yaml` and in `core/network/token_storage.dart` the whole time
  /// (ADR-0023 D6).
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

  /// Carries **nothing at all** — not in the URL, and not in `extra` either.
  ///
  /// `phoneNumber` is personal data and `verificationId`/`resendToken` are
  /// what Firebase uses to confirm a credential, so D6 kept all three off the
  /// URL. ADR-0018 **Amendment 2 (A2-D2)** took the next step and moved them
  /// out of `extra` as well, into `otpFlowProvider`: `extra` is JSON-encoded
  /// by go_router on the way into route restoration state, so a value it
  /// cannot encode silently became `null` and every `GoRouter.refresh()`
  /// threw the user out of the middle of the flow.
  ///
  /// A route that needs state reads it through `requireRouteState`. The
  /// negative assertions in `app_router_test.dart` and
  /// `login_screen_test.dart` still run — they now guard against the values
  /// coming *back*, rather than proving they stayed put.
  static const String otpPath = '/otp';
  static const String otpName = 'otp';

  /// Carries **nothing at all**, same reasoning and mechanism as
  /// [otpPath] (ADR-0021 D2, applying ADR-0018 Amendment 2 A2-D2): the
  /// email being verified lives in `emailVerificationFlowProvider`, read
  /// through `requireRouteState` like every other route that cannot render
  /// without state it doesn't own.
  static const String emailVerificationPath = '/verify-email';
  static const String emailVerificationName = 'emailVerification';

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

  /// The orders tab (SCR-07 B7). Placeholder screen only until SCR-09 wires
  /// up `GET /orders` — same `AuthGate` shape as [homePath], since a
  /// signed-out visitor has no orders to place either. Carries nothing:
  /// there is no argument this screen could render differently on.
  static const String ordersPath = '/orders';
  static const String ordersName = 'orders';

  /// The profile tab (SCR-07 B7). Same `AuthGate` shape as [homePath] —
  /// `AuthUser` only exists once signed in, and this screen reads it.
  static const String profilePath = '/profile';
  static const String profileName = 'profile';

  /// SCR-07 B1 — reached by pushing from `PosterDetailScreen`'s "ซื้อเลย"
  /// flow (B3, out of this slice) once a reservation exists. Carries
  /// **nothing at all**, same ADR-0018 Amendment 2 A2-D2 shape as [otpPath]:
  /// the reservation + poster snapshot live in `checkoutFlowProvider`, read
  /// through `requireRouteState` — there is no `/checkout/:reservationId`
  /// because there is no `GET /reservations/{id}` to recover the flow from
  /// a path parameter alone (GATE 1 §6 item 4).
  static const String checkoutPath = '/checkout';
  static const String checkoutName = 'checkout';

  /// SCR-07 AC-5 — the privacy notice. **Public**, unlike every other route
  /// below `homePath`: a PDPA notice has to be readable at the moment data
  /// is collected, not gated behind having already signed in, and this
  /// content has to be linkable from outside the app too (a support answer,
  /// a footer) without requiring a session.
  static const String privacyPath = '/privacy';
  static const String privacyName = 'privacy';

  /// Every path pattern above. Order is irrelevant; membership is not.
  static const List<String> allPaths = <String>[
    onboardingPath,
    homePath,
    registerPath,
    otpPath,
    emailVerificationPath,
    posterDetailPath,
    ordersPath,
    profilePath,
    checkoutPath,
    privacyPath,
  ];

  /// Every route name above, paired 1:1 with [allPaths].
  static const List<String> allNames = <String>[
    onboardingName,
    homeName,
    registerName,
    otpName,
    emailVerificationName,
    posterDetailName,
    ordersName,
    profileName,
    checkoutName,
    privacyName,
  ];
}
