# lib/features/auth/

Fully feature-first — the reference implementation of the whole Repository + UseCase chain described in root `CLAUDE.md`. Read this feature's source before building the same chain for a new feature.

```
domain/
  entities/       # AuthUser
  repositories/   # AuthRepository interface — signIn/signUp/signInWithGoogle/
                  # signInWithApple/signOut/authStateChanges
  usecases/       # one class per action (SignInWithEmailPassword, SignOut, ...)
data/
  datasources/    # AuthRemoteDataSource — wraps FirebaseAuth + GoogleSignIn +
                  # SignInWithApple SDK calls directly
  repositories/   # AuthRepositoryImpl — maps every SDK-specific exception
                  # (FirebaseAuthException, GoogleSignInException,
                  # SignInWithAppleAuthorizationException) into AuthException or
                  # AuthCancelledException from core/error/; user-cancelled social
                  # sign-in becomes AuthCancelledException (silent), everything
                  # else becomes AuthException
presentation/
  providers/      # full DI graph (datasource → repository → usecases) +
                  # AuthViewModel (AsyncNotifier<void>, AsyncValue.guard pattern)
  screens/        # LoginScreen — single form, mode-toggled between login/register
  auth_gate.dart  # gates a destination behind auth state (AuthGate)
```

- Google/Apple sign-in buttons are web-guarded (`kIsWeb` → `_showMobileOnly()` snackbar) since those SDKs are mobile-only here. The Apple button is currently hidden (`showAppleButton = false` in `login_screen.dart`) pending native entitlements — see `docs/social-login-setup.md`.
- `AuthGate` is the destination-agnostic gate: pass it any `WidgetBuilder` for the authenticated destination. Onboarding uses it as `AuthGate(builder: _buildHome)`.
- All user-facing copy in this feature comes from `AppStrings` (`core/strings/app_strings.dart`) — see that file's `// --- Auth ---` section. Some constants are deliberately reused across two different UI slots within this feature (e.g. `authSubmitLogin` for both the submit button and the mode-toggle link) because they're the same wording with the same meaning, just two roles.
