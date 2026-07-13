# CLAUDE.md

Architecture and coding guidelines for the **posternung** (Cinevault) Flutter app. Read this before adding or modifying code — it defines the conventions Claude (and any contributor) must follow in this repo.

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
  core/theme/                                    # design tokens (Figma-derived)
  features/onboarding/presentation/               # presentation-only feature, no data/domain layer yet
  auth/                                           # Firebase Auth (login/signup) — predates this architecture doc,
                                                   # not yet split into data/domain/presentation
  home/                                           # placeholder post-login screen
  main.dart
```

`auth/` and `home/` predate this document and are not yet reorganized into the feature-first layout — don't block unrelated work on migrating them, but new code in those areas should move toward this structure incrementally rather than add to the old one.

## General Rules

- No layer skips: presentation never imports `data/`; domain never imports Flutter or `data/`.
- Don't create `data/`/`domain/` folders for a feature that has no data dependency.
- Don't introduce a new state-management, DI, or mocking library without updating this file first.
