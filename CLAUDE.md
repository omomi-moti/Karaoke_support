# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Build & Test

This is an Xcode project with no external package manager. All builds and tests run through Xcode or `xcodebuild`.

```bash
# Build (simulator)
xcodebuild build \
  -project Karaoke_support/Karaoke_support.xcodeproj \
  -scheme Karaoke_support \
  -destination 'platform=iOS Simulator,name=iPhone 17'

# Run all unit tests
xcodebuild test \
  -project Karaoke_support/Karaoke_support.xcodeproj \
  -scheme Karaoke_support \
  -destination 'platform=iOS Simulator,name=iPhone 17'

# Run a single test class
xcodebuild test \
  -project Karaoke_support/Karaoke_support.xcodeproj \
  -scheme Karaoke_support \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:Karaoke_supportTests/HistoryViewModelPaginationTests
```

There is no linter configured. Swift compiler warnings serve as the lint signal.

---

## Architecture

**Stack**: SwiftUI + SwiftData (iOS 26+), `@Observable`, Swift Concurrency, no external dependencies.

**Pattern**: MVVM + Repository, manual DI via `@Environment`.

### Layer map

```
Sources/
├── App/          # @main, ModelContainer setup, EnvironmentKey definitions, preview mocks
├── Presentation/ # View + ViewModel (one ViewModel per screen)
├── Domain/       # Protocols, @Model entities, enums, helpers — no SwiftUI/Data imports
└── Data/         # Concrete repository implementations (SwiftData, NetworkMonitor) — no SwiftUI imports
```

**Dependency direction**: `Presentation → Domain Protocol`. `Data` implements Domain protocols and is injected at app startup. `Presentation` never imports `Data`.

### DI wiring

The `ModelContainer` and repositories are built in one place, `AppDependencies.make(configuration:)` (`Sources/App/AppDependencies.swift`). `KaraokeSupportApp` holds the result and injects the repositories via custom `EnvironmentKey` types defined in `Sources/App/Environment/`. Views read them with `@Environment(\.sessionRepository)` etc. and pass them into ViewModel `init`. Preview mocks live in `Sources/App/PreviewSupport/`.

If the persistent store cannot be opened, the app shows `DataLoadErrorView` instead of `RootView` and never falls back to an in-memory store; the original data is left untouched and the error is logged (ADR 0033). In Debug builds, launching with `KARAOKE_SIMULATE_DATA_LOAD_FAILURE=1` shows that screen.

How a value goes into the environment depends on whether its default has identity (ADR 0031):

- **Values and closures** (`historyReloadTick`, `navigateTo…`): `@Entry`. Its default is recomputed on every read when nothing is injected, which is harmless here.
- **Stateful reference types** (repositories): `EnvironmentKey` + `static let defaultValue`, so the preview default is created once. Repository protocols are `@MainActor` and `Sendable`, and preview repositories have a `nonisolated init()` so the key's default can be created off the main actor (ADR 0027).
- **The single `@Observable` app object** (`NetworkMonitor`): no key. Inject with `.environment(networkMonitor)` and read with `@Environment(NetworkMonitor.self)`. There is no default, so every preview that shows the recording sheet must inject `NetworkMonitor(startsMonitoring: false)`.

```swift
// Pattern — never do this in a View:
modelContext.insert(...)        // ❌ direct DB write from View
SessionRepository(...)          // ❌ instantiate concrete type in View

// Always go through Repository via ViewModel:
viewModel.save()                // ✅
```

### Key domain models

| Type | File | Notes |
|------|------|-------|
| `Track` | `Domain/Models/SwiftData/Track.swift` | `spotifyTrackId` OR `userEnteredName`; two convenience inits |
| `SingingSession` | `Domain/Models/SwiftData/SingingSession.swift` | UUID idempotency key; N:1 with Track |
| `Intent` | `Domain/Models/Enums/Intent.swift` | `.shout` / `.emo` / `.practice`; `String` RawValue |
| `RecordSource` | `Domain/Models/Enums/RecordSource.swift` | `.manual` / `.suggestion`; stored as optional `SingingSession.recordedSource`, read as `source` (nil = `.manual`) (ADR 0034) |

When adding a property to an `@Model`, make it optional: SwiftData's automatic migration leaves the new column empty on existing rows, and a non-optional enum crashes when read (ADR 0034). Open data from the previous build with the new build before shipping.

### ViewModel rules

- All ViewModels: `@Observable`, `@MainActor`, class. Never `ObservableObject` / `@StateObject` / `@ObservedObject`.
- One ViewModel per screen/tab.
- Repositories injected via `init` (never created inside ViewModel).
- `async throws` for all repository calls; errors caught in ViewModel, surfaced as state, and the UI offers a retry.

### View and data rules

- **Views only draw.** No repository calls, business logic, or async work in a View; delegate to the ViewModel. A container View may read repositories from `@Environment` and create the ViewModel (e.g. `IntentTabContainerView`, `SettingsContainerView`).
- **Property wrappers**: `@State` for transient UI state and for holding the ViewModel; `@Binding` for two-way state from a parent; `@Environment` for app-wide values (repositories, network state). Don't use `@Query` in Views; read through repositories (currently zero `@Query` in the app).
- **Repositories are `@MainActor`** because `ModelContext` is not thread-safe and must stay on the thread that created it.
- **`UserDefaults`** is only for UI flags (e.g. a tutorial-shown flag), never for displayed data or Spotify metadata (currently unused).
- Check connectivity before calling an API and fall back to local data when offline (V2, Spotify).

### Files and naming

- Put files in a feature subfolder under each layer (`Presentation/Recording/`, `Presentation/History/`, …).
- **One type per file, file name = type name.** A `#Preview` may live in the same file.
- **Every View that can be previewed has a `#Preview`** (skip only when it needs auth or a live API).
- Screens: `{Feature}View` / `{Role}View` (`HistoryListView`); reusable components: `{Purpose}{Kind}` (`TrackRowView`, `IntentBadgeView`).
- `@Model` entities: singular PascalCase (`Track`, `SingingSession`). Bool properties and variables start with `is` / `has` / `can`.
- Async functions start with a verb (`fetchSessions()`); repository methods use `save` / `fetch` / `update` / `delete` / `exists`; ViewModel methods name the user action (`save()`, `load()`).
- Protocols name a role (`SessionRepositoryProtocol`); enums are singular nouns with lowerCamelCase cases (`Intent { case shout, emo, practice }`).

---

## Patterns Originating from iOS 17 Constraints

The deployment target was raised to iOS 26 on 2026-09-23, so the iOS 17 bugs below no longer apply. The code still follows these patterns; don't change them without adding an ADR to `docs/adr/`.

**SwiftData `#Predicate` + enum** (ADR 0007, review candidate): `#Predicate { $0.intent == .shout }` crashed on iOS 17.0–17.2, so all intent-filtered fetches use `fetchAll` then `filter` in memory. See `SwiftDataSessionRepository.fetchByIntent`. Whether to move filtering back into the predicate on iOS 26 is undecided.

**Single sheet on `RootView`** (ADR 0008, superseded by ADR 0025): Originally adopted because using `NavigationStack` and `.sheet` in the same View corrupted navigation state after sheet dismiss on iOS 17.0. It is kept for its other benefits (no flicker on save, one sheet reachable from every tab). The sheet lives **once on `RootView`** (`.sheet(item: $sheet, onDismiss:)` on the `TabView`), not inside any tab's `NavigationStack`; the Songs tab's stack is root-only. It switches between the recording sheet and the after-save recommendation sheet (ADR 0024); every presentation goes through `present()`, which waits for the current sheet to finish dismissing before showing the next one. After a save, `RootView` bumps `historyReloadTick` so the History list reloads, switches to the History tab only after the recording sheet has finished dismissing, and shows the after-save sheet one second after that (ADR 0032). See `docs/v1_navigation_songs_recording.md`.

---

## Important Patterns

### Async race condition — `loadGeneration`

`HistoryViewModel` uses an `Int` counter (`loadGeneration`) to discard stale fetch completions. Increment on each new load; only apply results when the completed generation matches the current one. `Task.cancel()` alone is insufficient because cancellation is asynchronous.

### Idempotent save

`SessionRepository.save` checks `exists(uuid:)` before inserting. UI layer also disables the save button immediately (`isSaving` flag). Both guards are required — the UI guard alone cannot handle rapid double-taps.

### History snapshot pattern

`HistoryViewModel` maps `SingingSession` (SwiftData reference type) to `HistorySessionRowDisplayItem` (value type) immediately on fetch. The UI operates on the snapshot — optimistic deletes remove from the snapshot first, restore on failure. Max 500 rows; 20 per page, prefetch at 5 rows from bottom.

---

## Git Conventions

- **Branch naming**: `{type}/{short-english-name}` with no issue number (e.g. `feature/after-save-recommendation`, `fix/data-load-error`, `refactor/environment-keys`). `type` is `feature` / `fix` / `refactor` / `docs` / `chore`. One issue (one sprint) per branch, small enough to merge within a few days.
- **Linking issues**: put `Refs #N` in commit messages and `Closes #N` in the PR body, instead of in the branch name.
- **Commit message**: `{prefix}: {summary of 50 characters or less}`, with a body for what and why when needed. Prefixes: `feat:` / `fix:` / `refactor:` / `docs:` / `test:` / `chore:`
- **Merge**: squash merge via PR into `main`. No direct pushes to `main`. (The former integration branch `develop/ios26-redesign` was merged into `main` in #110 and is no longer used.)
- Rebasing inside a feature branch is fine; never rebase commits already pushed to `main`.

---

## Project Constraints (Constitution)

Summary of [docs/constitution.md](docs/constitution.md), which takes precedence over ADRs and other docs.

- **Spotify metadata must never be persisted** (SwiftData, UserDefaults, disk). In-memory TTL cache only (≤ 24h, reset on restart). V2 design; not yet implemented.
- **SSOT is local SwiftData**. API responses are never rendered directly in Views.
- **Offline first**: recording and browsing history must work without a network. Intents and memos stay on the device and are never sent out.
- **`Track` and `SingingSession` stay separate**: deduplicate tracks only; a new `SingingSession` is created for every performance.
- **`userEnteredName`** is user-generated data (persistable). `spotifyTrackId` is Spotify metadata (identifier only, persistable as a key). Artwork/title/artist from Spotify API are NOT persistable.
- Tasks and spec changes are tracked in GitHub Issues; design decisions are recorded in `docs/adr/`. The old issue lists (`docs/archive/v1_issues.md` etc.) are archived and only used to look up the `I-0xx` numbers that appear in code comments.

---

## Test Layout

```
Karaoke_supportTests/
├── App/                 # AppDependencies
├── Data/SwiftData/      # in-memory ModelContainer tests for repository operations
├── Domain/              # Helper and model unit tests (e.g. NextTrackRecommender)
└── Presentation/
    ├── AfterSave/       # after-save recommendation
    ├── History/         # HistoryViewModel pagination, sort, loadGeneration
    ├── Recording/       # RecordingSheetViewModel save/edit, record source, track suggestions, score input
    ├── Settings/        # SettingsViewModel
    ├── Songs/           # IntentTabViewModel
    ├── TrackDetail/     # TrackDetailViewModel, score summary
    └── Common/
```

Tests that touch SwiftData use a real `ModelContainer(isStoredInMemoryOnly: true)` — no mocking of the DB layer. ViewModel tests inject mock repositories via protocol. New tests use Swift Testing (`@Suite` / `@Test`).

---

## Related Files

- docs/constitution.md — プロジェクト最上位ルール（要点は上の Project Constraints）
- docs/adr/ — 技術判断の記録（ADR、1 件 1 ファイル）。設計判断を決めた・変えたときは 1 件足す。承認済みの本文は書き換えず、新しい番号で置き換える。書き方は docs/adr/README.md
- docs/README.md — docs の目次と、どの文書が正か
- .claude/skills/karaoke-review/ — このプロジェクト用のコードレビュー
