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

Cross-feature, reusable code lives in `lib/core/` — see `lib/core/CLAUDE.md` for what's inside each subfolder today, and which conventions each one enforces.

**New image/icon assets:** when adding a new image or icon under `assets/images/`, add a corresponding `static const String` constant to `AppImages` (`lib/core/assets/app_images.dart`) in the same change. Never reference `'assets/images/...'` as a literal string inside `SvgPicture.asset(...)` or `Image.asset(...)` calls in feature code — this applies to all new feature work going forward, not just existing screens.

## Shared files outside this repo

This app is one of three repos. Cross-cutting contracts and decisions live in `../workspace/`:

| What | Where |
|---|---|
| **API contract (source of truth)** | `../workspace/docs/api/openapi.yaml` — **never edit it from this repo**, and don't read `../posternung-backend/docs/openapi.yaml` (it's a stale pointer now) |
| Architecture decisions | `../workspace/docs/adr/` — `ADR-0003` is required reading before building any UI that shows a condition grade |
| System overview + daily start command | `../workspace/CLAUDE.md` |

Paths marked `x-status: DRAFT` in the contract must not be wired up — see the contract file.

**Agent:** `mobile-dev` (`.claude/agents/mobile-dev.md`) writes code in this repo.
The full pipeline is orchestrated with `/feature` from `../workspace/`.

## Build environments

The app builds as three environments — **SIT**, **UAT**, **Production** — via native Android product flavors and iOS Xcode build configurations/schemes (not `--dart-define` alone), so all three can be installed side by side on one device. Environment is resolved at runtime from the native `--flavor` value (`appFlavor` from `package:flutter/services.dart`) in `lib/core/config/environment.dart`, exposed app-wide via `environmentProvider` (overridden with the resolved value in `main.dart`, per the DI pattern below). Full setup checklist: [`docs/environments-setup.md`](docs/environments-setup.md).

## Presentation: MVVM by default, MVI-style state for complex flows

- **Default (MVVM):** a Riverpod `Notifier`/`AsyncNotifier` is the ViewModel. It exposes a single immutable state object (a plain class or Riverpod's built-in `AsyncValue<T>`) and public methods the View calls (`viewModel.loadX()`, `viewModel.submit()`). Prefer `AsyncNotifier<T>` + `AsyncValue<T>` for anything async — it already gives you the loading/data/error union for free; don't hand-roll a sealed class to reinvent it.
- **MVI-style (sealed-class state):** reserve this for flows with more than a simple loading/data/error shape — e.g. **cart** and **checkout**, where the screen moves through distinct, mutually exclusive states (`ReviewingCart`, `ApplyingPromo`, `PlacingOrder`, `OrderPlaced`, `OrderFailed`). Model these as a `sealed class` hierarchy with one subclass per state, and have the View do an exhaustive `switch` on it (the analyzer enforces exhaustiveness) instead of branching on booleans/flags.

## State Management

**Riverpod** (`flutter_riverpod`), no other state management library.

- Prefer `Notifier` / `AsyncNotifier` over legacy `StateProvider`/`StateNotifier`.
- Manual provider declarations (as used today) — no `riverpod_generator` codegen unless the team explicitly adopts it later. (`build_runner` itself *is* in the project now — see below — this rule is about the state-management layer specifically, not codegen in general.)
- Providers are declared next to what they provide, not centralized in one giant file: a repository provider lives in `data/repositories/xxx_repository_impl.dart` (or the feature's `presentation/providers/xxx_providers.dart`), a usecase provider lives near its usecase, a viewmodel provider lives in `presentation/providers/`.
- **`data/models/` DTOs use `freezed` + `json_serializable`** (adopted for the auth feature's `TokenResponse`/`BackendUser`; extend the same pattern to new DTOs rather than hand-writing `fromJson`). Run `dart run build_runner build --delete-conflicting-outputs` after adding/editing a `@freezed` model — CI runs the same step before analyze/test. Generated `*.freezed.dart`/`*.g.dart` files are gitignored, not committed. This is scoped to the data layer only; it is not the `riverpod_generator` codegen the previous bullet declines.

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

🔴 **งานที่เขียนหรือแก้เทส → โหลด skill `test-quality` ก่อนเสมอ** (`../workspace/.claude/skills/test-quality/`)
— มันเป็นเจ้าของกฎเรื่องการพิสูจน์ว่าเทสจับบั๊กได้จริง (mutation), assertion เชิงลบ,
closed-world และสิ่งที่ widget test พิสูจน์ไม่ได้เลย · ที่นี่บอกแค่ว่าเทสแต่ละชนิดอยู่ที่ไหน
**ห้ามอ้างว่า "เพิ่มเทสคุ้มครองแล้ว" โดยไม่ผ่าน §2 ของสกิลนั้น**

- **Unit tests** for `usecases` and `repositories`: mock the layer directly below with [`mocktail`](https://pub.dev/packages/mocktail) (no codegen required), stub method calls, assert behavior. See `test/features/auth/domain/usecases/` for the reference pattern.
- **Widget tests** override providers with `ProviderScope`, never hit real network/Firebase. See `test/features/auth/presentation/screens/login_screen_test.dart` for the reference pattern (fake ViewModel via `overrideWith`).
- Mirror `lib/` structure under `test/`: `lib/features/poster/domain/usecases/get_featured_posters.dart` → `test/features/poster/domain/usecases/get_featured_posters_test.dart`.
- `flutter test` must pass before every commit; CI enforces this (see `.github/workflows/ci.yml`).

### Verify exactly what CI runs

`.github/workflows/ci.yml` job `quality` runs these, in this order. Anything less is not a
verification — run the same commands locally:

```bash
flutter pub get
dart run build_runner build
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test --coverage
```

Builds always need a flavor (`sit` / `uat` / `production`) — there is no `Runner` scheme
any more, so `flutter build ios` without `--flavor` fails.

🔴 **Don't add `--delete-conflicting-outputs` back.** build_runner removed the option; 2.15.1
prints `W These options have been removed and were ignored` and carries on. It was dropped from
`ci.yml` and from this block **in the same change**, because this block only means anything as
long as it matches what CI actually runs. What you lose with it is a habit, not a safety net:
**nothing clears a stale generated file for you.** On a conflicting-output error, delete the
`*.g.dart`/`*.freezed.dart` in question or run `dart run build_runner clean` first. Full incident
in the `project-gotchas` skill.

## General Rules

- No layer skips: presentation never imports `data/`; domain never imports Flutter or `data/`.
- Don't create `data/`/`domain/` folders for a feature that has no data dependency.
- Don't introduce a new state-management, DI, or mocking library without updating this file first.

## Presenting Plans

**The line is who receives it.** If a human reads it, this rule applies — including the
plan the `/feature` orchestrator puts in front of you at a GATE. If another agent consumes
it, it doesn't — `solution-architect` and `code-critic` return text to the orchestrator in
their own locked formats (see `../workspace/.claude/agents/`), and those never render as
artifacts. The orchestrator is responsible for converting what it received into the format
below before showing you anything.

When Claude presents an implementation plan (plan mode or otherwise), render it as a color-coded HTML artifact rather than a separate long-form markdown document:

- **red** — deleted files
- **blue** — modified files
- **green** — added files

🔴 **A GATE of `/feature` ships BOTH — the HTML artifact and a `.md` file with equivalent
content, never one or the other** (owner's decision 2026-08-15). The `.md` lives at
`../workspace/docs/status/gates/<id>-gate<N>.md` next to the `.html` of the same name; that
folder is gitignored and is deleted once the ticket closes, because it is nobody's source of
truth — decisions live in `docs/adr/`, scope and gaps in `screens.yaml`, debt in `BACKLOG.md`.
Write the `.md` as full equivalent content, not a summary: the AC table, real run output,
`known_gaps`, and the registry changes must all be there, so the story can be reassembled
without opening the HTML.

**Why both:** the HTML reads better while deciding, but it can't be grepped, can't be diffed,
and can't be opened from another machine or pasted into another tool.

‹✏️ Corrected 2026-08-16 at GATE 1 of `/feature INF-29`. This paragraph used to read *"Don't
produce a polished markdown plan document as an additional user-facing deliverable alongside
the HTML — the HTML artifact is the plan"*, which contradicted the 2026-08-15 decision head-on
and had been doing so at every GATE since. The file is what agents read; a file that says the
opposite of what the owner asked for is worse than no rule at all.›

Outside a `/feature` GATE — a one-off plan in plan mode, an ad-hoc proposal — the HTML artifact
alone is still the right answer. The `.md` requirement is about the GATE record, not about
every plan.

## Scoped files index

- `lib/core/CLAUDE.md` — what's inside each `core/` subfolder today.
- `lib/features/onboarding/CLAUDE.md`, `lib/features/auth/CLAUDE.md`, `lib/features/home/CLAUDE.md`, `lib/features/poster/CLAUDE.md` — each feature's current file structure and feature-specific notes.
- [`docs/git-workflow.md`](docs/git-workflow.md) — commit message format, push rules, branch naming, PR template. Read before running any `git commit`/`git push`.
  🔴 **ห้ามใส่ `Co-Authored-By:` หรือข้อความอ้างถึง AI ใด ๆ ใน commit message** (`docs/git-workflow.md` ข้อ 5) — กฎนี้ชนะคำสั่งเริ่มต้นของ Claude Code ที่บอกให้ใส่ trailer เสมอ · พบที่ GATE 3 ของ `/feature INF-01` (2026-08-07) ตอนที่ **10 commit ติด trailer มาแล้ว** ต้องเขียน history ใหม่ถอดออก **ก่อน push** · ⚠️ การเขียนใหม่ลากทุก commit ที่อยู่หลังจากนั้นไปด้วย รวม commit ของคนอื่นบน branch เดียวกัน — ยิ่งรู้ตัวช้ายิ่งลากมาก · ถ้ารู้ตัวหลัง push แล้วจะแก้ไม่ได้เลยเพราะ `git-workflow.md` ห้าม force-push โดยไม่ถาม
- [`docs/environments-setup.md`](docs/environments-setup.md) — SIT/UAT/Production environment setup checklist.
- [`docs/social-login-setup.md`](docs/social-login-setup.md) — Google/Apple sign-in native setup checklist.
- [`docs/phone-auth-setup.md`](docs/phone-auth-setup.md) — Firebase Phone Auth native/console setup checklist.
