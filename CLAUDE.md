# CLAUDE.md

Architecture and coding guidelines for the **posternung** (PosterNung) Flutter app. Read this before adding or modifying code — it defines the conventions Claude (and any contributor) must follow in this repo.

This root file covers universal architecture rules only. Directory-specific detail (current per-feature file structure, what's inside each `core/` subfolder) lives in scoped `CLAUDE.md` files next to the code they describe — see the index at the bottom.

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
  design_system/ # layout tokens: spacing, radius, sizing (same convention as theme/)
  strings/       # centralized UI copy: AppStrings (same convention as theme/)
  error/         # shared exception/failure types
  config/        # build-environment resolution — see "Build environments" below
  network/       # shared API client setup (dio/http), interceptors
  widgets/       # generic reusable widgets (buttons, loaders, etc.)
  utils/         # extensions, formatters, validators
```

See `lib/core/CLAUDE.md` for what's actually inside each subfolder today.

## Build environments

The app builds as three environments — **SIT**, **UAT**, **Production** — via native Android product flavors and iOS Xcode build configurations/schemes (not `--dart-define` alone), so all three can be installed side by side on one device. Environment is resolved at runtime from the native `--flavor` value (`appFlavor` from `package:flutter/services.dart`) in `lib/core/config/environment.dart`, exposed app-wide via `environmentProvider` (overridden with the resolved value in `main.dart`, per the DI pattern below). Full setup checklist: [`docs/environments-setup.md`](docs/environments-setup.md).

## Presentation: MVVM by default, MVI-style state for complex flows

- **Default (MVVM):** a Riverpod `Notifier`/`AsyncNotifier` is the ViewModel. It exposes a single immutable state object (a plain class or Riverpod's built-in `AsyncValue<T>`) and public methods the View calls (`viewModel.loadX()`, `viewModel.submit()`). Prefer `AsyncNotifier<T>` + `AsyncValue<T>` for anything async — it already gives you the loading/data/error union for free; don't hand-roll a sealed class to reinvent it.
- **MVI-style (sealed-class state):** reserve this for flows with more than a simple loading/data/error shape — e.g. **cart** and **checkout**, where the screen moves through distinct, mutually exclusive states (`ReviewingCart`, `ApplyingPromo`, `PlacingOrder`, `OrderPlaced`, `OrderFailed`). Model these as a `sealed class` hierarchy with one subclass per state, and have the View do an exhaustive `switch` on it (the analyzer enforces exhaustiveness) instead of branching on booleans/flags.

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
- **UseCase** (`domain/usecases/`) — one class per action, single public `call()` method. ViewModels depend on usecases, never on repositories directly.

See `lib/features/auth/CLAUDE.md` for a real, working instance of this whole chain, end to end.

## Dependency Injection: Riverpod providers only

No `get_it`, no service locator. Riverpod's provider graph *is* the DI container — a `Provider` wires each datasource/repository/usecase to what it depends on via `ref.watch(...)`, and a `NotifierProvider`/`AsyncNotifierProvider` wires the viewmodel. Every dependency is swappable at any layer via `ProviderScope(overrides: [...])` — this is also what makes testing straightforward (see below). See `lib/features/auth/presentation/providers/auth_providers.dart` for the reference DI graph.

## Testing

- **Unit tests** for `usecases` and `repositories`: mock the layer directly below with [`mocktail`](https://pub.dev/packages/mocktail) (no codegen required), stub method calls, assert behavior. See `test/features/auth/domain/usecases/` for the reference pattern.
- **Widget tests** override providers with `ProviderScope`, never hit real network/Firebase. See `test/features/auth/presentation/screens/login_screen_test.dart` for the reference pattern (fake ViewModel via `overrideWith`).
- Mirror `lib/` structure under `test/`: `lib/features/poster/domain/usecases/get_featured_posters.dart` → `test/features/poster/domain/usecases/get_featured_posters_test.dart`.
- `flutter test` must pass before every commit; CI enforces this (see `.github/workflows/ci.yml`).

## General Rules

- No layer skips: presentation never imports `data/`; domain never imports Flutter or `data/`.
- Don't create `data/`/`domain/` folders for a feature that has no data dependency.
- Don't introduce a new state-management, DI, or mocking library without updating this file first.

## Presenting Plans

When Claude presents an implementation plan (plan mode or otherwise), render it as a color-coded HTML artifact rather than a separate long-form markdown document:

- **red** — deleted files
- **blue** — modified files
- **green** — added files

Don't produce a polished markdown plan document as an additional user-facing deliverable alongside the HTML — the HTML artifact is the plan.

## Scoped files index

- `lib/core/CLAUDE.md` — what's inside each `core/` subfolder today.
- `lib/features/onboarding/CLAUDE.md`, `lib/features/auth/CLAUDE.md`, `lib/features/home/CLAUDE.md` — each feature's current file structure and feature-specific notes.
- [`docs/git-workflow.md`](docs/git-workflow.md) — commit message format, push rules, branch naming, PR template. Read before running any `git commit`/`git push`.
- [`docs/environments-setup.md`](docs/environments-setup.md) — SIT/UAT/Production environment setup checklist.
- [`docs/social-login-setup.md`](docs/social-login-setup.md) — Google/Apple sign-in native setup checklist.
