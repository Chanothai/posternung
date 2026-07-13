# CLAUDE.md

Architecture and coding guidelines for the **posternung** (PosterNung) Flutter app. Read this before adding or modifying code — it defines the conventions Claude (and any contributor) must follow in this repo.

## Overall Architecture

**Clean Architecture, feature-first.** Each feature is a vertical slice under `lib/features/<feature_name>/` with up to three layers:

```
lib/features/<feature_name>/
  data/                    # how data is fetched/stored
    datasources/           # remote (REST/Firestore/etc.) and local (cache/prefs) sources
    models/                # DTOs — fromJson/toJson, map to/from domain entities
    repositories/          # concrete implementations of domain repository interfaces
  domain/                  # pure business logic, no Flutter/Firebase imports
    entities/              # plain domain objects
    repositories/          # abstract repository interfaces
    usecases/              # one class per use case (Interactor pattern)
  presentation/            # UI + view state
    providers/             # Riverpod providers wiring datasource → repository → usecase → viewmodel
    state/                 # sealed-class state (MVI-style), only where genuinely needed
    screens/               # pages / routes
    widgets/                # feature-local widgets not reused elsewhere
```

**A feature only has the layers it needs.** A purely presentational feature with no data dependency (e.g. `onboarding`) has no `data/` or `domain/` folder — don't scaffold empty layers "for consistency." Add `data/` and `domain/` the moment the feature actually talks to a repository.

Cross-feature, reusable code lives in `lib/core/`:

```
lib/core/
  theme/         # design tokens: colors, text styles
  error/         # shared exception/failure types
  network/       # shared API client setup (dio/http), interceptors
  widgets/       # generic reusable widgets (buttons, loaders, etc.)
  utils/         # extensions, formatters, validators
```

## Presentation: MVVM by default, MVI-style state for complex flows

- **Default (MVVM):** a Riverpod `Notifier`/`AsyncNotifier` is the ViewModel. It exposes a single immutable state object (a plain class or Riverpod's built-in `AsyncValue<T>`) and public methods the View calls (`viewModel.loadX()`, `viewModel.submit()`). Prefer `AsyncNotifier<T>` + `AsyncValue<T>` for anything async — it already gives you the loading/data/error union for free; don't hand-roll a sealed class to reinvent it.
- **MVI-style (sealed-class state):** reserve this for flows with more than a simple loading/data/error shape — e.g. **cart** and **checkout**, where the screen moves through distinct, mutually exclusive states (`ReviewingCart`, `ApplyingPromo`, `PlacingOrder`, `OrderPlaced`, `OrderFailed`). Model these explicitly:

  ```dart
  sealed class CheckoutState {
    const CheckoutState();
  }
  class CheckoutReviewing extends CheckoutState {
    const CheckoutReviewing(this.cart);
    final Cart cart;
  }
  class CheckoutPlacingOrder extends CheckoutState {
    const CheckoutPlacingOrder(this.cart);
    final Cart cart;
  }
  class CheckoutOrderPlaced extends CheckoutState {
    const CheckoutOrderPlaced(this.order);
    final Order order;
  }
  class CheckoutOrderFailed extends CheckoutState {
    const CheckoutOrderFailed(this.message);
    final String message;
  }
  ```

  The View does an exhaustive `switch` on the sealed state (the analyzer enforces exhaustiveness) instead of branching on booleans/flags.

## State Management

**Riverpod** (`flutter_riverpod`), no other state management library.

- Prefer `Notifier` / `AsyncNotifier` over legacy `StateProvider`/`StateNotifier`.
- Manual provider declarations (as used today) — no `riverpod_generator`/`build_runner` codegen unless the team explicitly adopts it later.
- Providers are declared next to what they provide, not centralized in one giant file: a repository provider lives in `data/repositories/xxx_repository_impl.dart` (or the feature's `presentation/providers/xxx_providers.dart`), a usecase provider lives near its usecase, a viewmodel provider lives in `presentation/providers/`.

## Data Flow: Repository Pattern + UseCase (Interactor) Pattern

```
View (ConsumerWidget)
  → watches → ViewModel (Notifier/AsyncNotifier)
      → calls → UseCase (single `call()` method, one class per use case)
          → calls → Repository (abstract interface, domain layer)
              → implemented by → RepositoryImpl (data layer)
                  → calls → DataSource (remote/local)
```

- **Entity** (`domain/entities/`) — plain, no serialization, no Flutter imports.
- **Model** (`data/models/`) — DTO with `fromJson`/`toJson`, converts to/from the domain entity via a `toEntity()`/`fromEntity()` method.
- **Repository interface** (`domain/repositories/`) — abstract class, returns/throws domain-level types only (no `DioException`, no Firestore exceptions leaking upward).
- **RepositoryImpl** (`data/repositories/`) — catches data-source exceptions and rethrows as domain exceptions (`ServerException`, `CacheException`, etc. from `core/error/`).
- **UseCase** (`domain/usecases/`) — one class per action, single public `call()` method:

  ```dart
  class GetFeaturedPosters {
    GetFeaturedPosters(this._repository);
    final PosterRepository _repository;

    Future<List<Poster>> call() => _repository.getFeatured();
  }
  ```

  ViewModels depend on usecases, never on repositories directly.

  See `lib/features/auth/` for a real, working instance of this whole chain: `domain/repositories/auth_repository.dart` (interface) → `data/repositories/auth_repository_impl.dart` (maps `FirebaseAuthException` → domain `AuthException` from `core/error/`) → `domain/usecases/sign_in_with_email_password.dart` → `presentation/providers/auth_providers.dart` (`AuthViewModel`) → `presentation/screens/login_screen.dart`.

## Dependency Injection: Riverpod providers only

No `get_it`, no service locator. Riverpod's provider graph *is* the DI container:

```dart
final posterRemoteDataSourceProvider = Provider<PosterRemoteDataSource>(
  (ref) => PosterRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final posterRepositoryProvider = Provider<PosterRepository>(
  (ref) => PosterRepositoryImpl(ref.watch(posterRemoteDataSourceProvider)),
);

final getFeaturedPostersProvider = Provider(
  (ref) => GetFeaturedPosters(ref.watch(posterRepositoryProvider)),
);

final posterListViewModelProvider =
    AsyncNotifierProvider<PosterListViewModel, List<Poster>>(
  PosterListViewModel.new,
);
```

Every dependency is swappable at any layer via `ProviderScope(overrides: [...])` — this is also what makes testing straightforward (see below).

## Testing

- **Unit tests** for `usecases` and `repositories`: mock the layer directly below with [`mocktail`](https://pub.dev/packages/mocktail) (no codegen required), stub method calls, assert behavior.

  ```dart
  class MockPosterRepository extends Mock implements PosterRepository {}

  void main() {
    late MockPosterRepository repository;
    late GetFeaturedPosters usecase;

    setUp(() {
      repository = MockPosterRepository();
      usecase = GetFeaturedPosters(repository);
    });

    test('returns featured posters from the repository', () async {
      when(() => repository.getFeatured()).thenAnswer((_) async => [tPoster]);
      final result = await usecase();
      expect(result, [tPoster]);
      verify(() => repository.getFeatured()).called(1);
    });
  }
  ```

- **Widget tests** override providers with `ProviderScope`, never hit real network/Firebase:

  ```dart
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        posterListViewModelProvider.overrideWith(() => FakePosterListViewModel()),
      ],
      child: const MaterialApp(home: PosterListScreen()),
    ),
  );
  ```

- Mirror `lib/` structure under `test/`: `lib/features/poster/domain/usecases/get_featured_posters.dart` → `test/features/poster/domain/usecases/get_featured_posters_test.dart`.
- `flutter test` must pass before every commit; CI enforces this (see `.github/workflows/ci.yml`).

## Current State of the Codebase (reference)

```
lib/
  core/
    theme/                                        # design tokens (Figma-derived): AppColors, AppTextStyles
    error/                                         # shared domain exception types (AuthException, ...)
    widgets/                                       # cross-feature widgets (AppGradientBackground, ...)
  features/
    onboarding/
      presentation/
        providers/                                 # OnboardingController — shared page-index state, 3 pages
        screens/                                    # OnboardingFirstScreen, OnboardingAuthenticateScreen,
                                                     # OnboardingLimitStockScreen — presentation-only, no
                                                     # data/domain layer (no data dependency, per the rule above)
        widgets/                                    # shared onboarding chrome: header, footer, progress dots,
                                                     # primary button — extracted once 2+ screens needed them
    auth/
      domain/                                       # AuthUser entity, AuthRepository interface, sign-in/sign-up
                                                     # usecases
      data/                                         # AuthRemoteDataSource + AuthRepositoryImpl
      presentation/
        providers/                                  # DI graph + AuthViewModel (AsyncNotifier)
        screens/                                    # LoginScreen (login/register, mode-toggled)
        auth_gate.dart                               # gates a destination behind auth state
  home/                                            # placeholder post-login screen — stock Flutter counter demo
  main.dart
```

`onboarding` and `auth` are both fully feature-first. `home/` is the only part of the app that still predates this document — don't block unrelated work migrating it, but new code there should move toward `features/home/` incrementally rather than add to the old flat location.

## General Rules

- No layer skips: presentation never imports `data/`; domain never imports Flutter or `data/`.
- Don't create `data/`/`domain/` folders for a feature that has no data dependency.
- Don't introduce a new state-management, DI, or mocking library without updating this file first.

---

## Git Commit Workflow

### เมื่อถูกขอให้ "commit" งาน ให้ทำตามลำดับนี้เสมอ

1. รัน `git status` และ `git diff` ก่อนเสมอ เพื่อดูว่ามีอะไรเปลี่ยนบ้าง
2. **แยก commit ตามความหมาย ไม่รวมทุกอย่างเป็น commit เดียว** — ถ้า diff มีทั้ง feature ใหม่ + fix bug ที่ไม่เกี่ยวกัน ให้ `git add` แยกไฟล์ และสร้างหลาย commit
3. รัน `flutter analyze` และ `flutter test` ก่อน commit ทุกครั้ง — ถ้ามี error/failing test ให้แจ้งผู้ใช้ก่อน ไม่ commit โค้ดที่พังทับไป
4. เขียน commit message ตาม **Conventional Commits** format ด้านล่างเป๊ะๆ
5. ห้ามใส่ข้อความอ้างอิงเครื่องมือ AI ใน commit message (เช่น "Generated by Claude" หรือ emoji ตกแต่ง) — commit message ต้องอ่านเหมือนวิศวกรจริงเขียนเอง

### Commit Message Format (บังคับ)

```
<type>(<scope>): <subject>

<body — optional, อธิบายว่าทำไม ไม่ใช่ทำอะไร>

<footer — optional, เช่น Closes #123, BREAKING CHANGE: ...>
```

**Types ที่ใช้ได้**: `feat` `fix` `refactor` `perf` `test` `docs` `style` `chore` `build` `ci` `revert`

**Scope**: ต้องตรงกับชื่อ folder ใน `lib/features/<scope>/` เช่น `onboarding`, `auth` (ปัจจุบัน), หรือ `cart`, `checkout`, `payment` (feature ในอนาคต) — สำหรับโค้ดที่ยังไม่ได้ย้ายเข้า feature-first layout ใช้ชื่อ folder เดิมได้ (เช่น `home`)
ถ้าเป็นงานข้าม feature ทั้งหมด (เช่น dependency, CI) scope เป็น `deps`, `ci`, `config` แทน

**Subject**: imperative mood, ตัวพิมพ์เล็ก, ไม่มีจุดปิดท้าย, ≤ 50 ตัวอักษร
ตัวอย่างที่ถูกต้อง: `feat(onboarding): add progress dots to hero screen`
ตัวอย่างที่ผิด: `Fixed some bugs in onboarding` / `updates`

### ตัวอย่าง commit ที่ดี
```
feat(onboarding): add progress dots to hero screen
fix(auth): prevent duplicate submit on rapid tap
refactor(auth): extract token storage into secure_storage_service
test(onboarding): add widget test for skip button
chore(deps): bump riverpod to 3.4.0
```

---

## Git Push Workflow

1. **ก่อน push ทุกครั้ง** ให้สรุปให้ผู้ใช้เห็นก่อนว่าจะ push commit อะไรบ้าง (`git log origin/<branch>..HEAD --oneline`)
2. **ห้าม push ตรงเข้า `main`/`master` โดยไม่ถามยืนยันก่อน** — ให้ push ไป feature branch แล้วเปิด PR แทนเสมอ ยกเว้นผู้ใช้ระบุชัดเจนว่าอนุญาตให้ push main
3. ถ้า branch ปัจจุบันคือ `main`/`master` และผู้ใช้ขอ commit งานใหม่ ให้ถามก่อนว่าต้องการสร้าง feature branch ใหม่หรือไม่ (ตาม branch naming ด้านล่าง)
4. หลัง push สำเร็จ ถ้าผู้ใช้ต้องการเปิด Pull Request ให้ใช้ `gh pr create` พร้อม title/description ที่สรุปการเปลี่ยนแปลงจาก commit history (ไม่ใช่ copy commit message ตรงๆ)

### Branch Naming Convention
```
feature/<scope>-<short-description>   เช่น feature/onboarding-progress-dots
fix/<scope>-<short-description>       เช่น fix/auth-race-condition
chore/<short-description>             เช่น chore/upgrade-riverpod
```

---

## Pull Request Description Template (เมื่อสร้าง PR ให้)

```markdown
## What
<สรุปสั้นๆ ว่า PR นี้ทำอะไร>

## Why
<เหตุผล/ปัญหาที่แก้>

## How to test
- [ ] ขั้นตอนทดสอบ 1
- [ ] ขั้นตอนทดสอบ 2

## Screenshots (ถ้ามี UI เปลี่ยน)
```

---

## สิ่งที่ห้ามทำโดยไม่ถามก่อน
- ห้าม force push (`git push -f`) โดยไม่ได้รับการยืนยันจากผู้ใช้อย่างชัดเจน
- ห้าม `git commit --amend` กับ commit ที่ push ไปแล้วโดยไม่ถามก่อน
- ห้าม rewrite history (`rebase -i` ของ commit เก่า) โดยไม่ถามก่อน
