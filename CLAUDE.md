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
  -destination 'platform=iOS Simulator,name=iPhone 16'

# Run all unit tests
xcodebuild test \
  -project Karaoke_support/Karaoke_support.xcodeproj \
  -scheme Karaoke_support \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# Run a single test class
xcodebuild test \
  -project Karaoke_support/Karaoke_support.xcodeproj \
  -scheme Karaoke_support \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:Karaoke_supportTests/HistoryViewModelPaginationTests
```

There is no linter configured. Swift compiler warnings serve as the lint signal.

---

## Architecture

**Stack**: SwiftUI + SwiftData (iOS 17+), `@Observable`, Swift Concurrency, no external dependencies.

**Pattern**: MVVM + Repository, manual DI via `@Environment`.

### Layer map

```
Sources/
├── App/          # @main, ModelContainer setup, EnvironmentKey definitions, preview mocks
├── Presentation/ # View + ViewModel (one ViewModel per screen)
├── Domain/       # Protocols, @Model entities, enums, helpers — no SwiftUI/Data imports
└── Data/         # Concrete repository implementations (SwiftData, NetworkMonitor)
```

**Dependency direction**: `Presentation → Domain Protocol`. `Data` implements Domain protocols and is injected at app startup. `Presentation` never imports `Data`.

### DI wiring

Repositories are instantiated in `KaraokeSupportApp.swift` with a `ModelContainer`, then injected via custom `EnvironmentKey` types defined in `Sources/App/Environment/`. Views read them with `@Environment(\.sessionRepository)` etc. and pass them into ViewModel `init`. Preview mocks live in `Sources/App/PreviewSupport/`.

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

### ViewModel rules

- All ViewModels: `@Observable`, `@MainActor`, class.
- One ViewModel per screen/tab.
- Repositories injected via `init` (never created inside ViewModel).
- `async throws` for all repository calls; errors caught in ViewModel, surfaced as `@Published`-like state.

---

## Known iOS 17 Constraints

**SwiftData `#Predicate` + enum**: `#Predicate { $0.intent == .shout }` crashes on iOS 17.0–17.2. All intent-filtered fetches use `fetchAll` then `filter` in memory. See `SwiftDataSessionRepository.fetchByIntent`.

**NavigationStack + `.sheet` co-existence bug (iOS 17.0)**: Using both in the same View corrupts `NavigationStack` state after sheet dismiss. The recording sheet therefore lives **once on `RootView`** (`.sheet(item: $recordingSheetItem)` on the `TabView`), not inside any tab's `NavigationStack`; the Songs tab's stack is root-only. After a save, `RootView` bumps `historyReloadTick` so the History list reloads even when the sheet was opened on the History tab. See `docs/v1_navigation_songs_recording.md`.

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

- **Branch naming**:
  - `feature/i-{番号}-{英語名}` (e.g. `feature/i-014-history-infinite-scroll`)
  - `refactor/i-r{番号}-{内容}`
  - `docs/i-d{番号}-{内容}`
  - `chore/i-c{番号}-{内容}`
- **Commit prefix**: `feat:` / `fix:` / `refactor:` / `docs:` / `test:` / `chore:`
- **Merge**: squash merge into `main` via PR. No direct pushes to `main`.

---

## Project Constraints (Constitution)

- **Spotify metadata must never be persisted** (SwiftData, UserDefaults, disk). In-memory TTL cache only (≤ 24h, reset on restart). V2 design; not yet implemented.
- **SSOT is local SwiftData**. API responses are never rendered directly in Views.
- **`userEnteredName`** is user-generated data (persistable). `spotifyTrackId` is Spotify metadata (identifier only, persistable as a key). Artwork/title/artist from Spotify API are NOT persistable.
- The authoritative spec for V1 scope is `docs/v1_issues.md`.

---

## Test Layout

```
Karaoke_supportTests/
├── Data/SwiftData/      # in-memory ModelContainer tests for repository operations
├── Domain/              # Helper and model unit tests
└── Presentation/
    ├── History/         # HistoryViewModel pagination, sort, loadGeneration
    ├── Recording/       # RecordingSheetViewModel save/edit
    ├── Songs/           # IntentTabViewModel
    └── Common/
```

Tests that touch SwiftData use a real `ModelContainer(isStoredInMemoryOnly: true)` — no mocking of the DB layer. ViewModel tests inject mock repositories via protocol.

---

## Related Files

- @.cursorrules — 詳細なコーディング規約・命名規則
- @docs/v1_issues.md — V1スコープのSingle Source of Truth
- @.specify/memory/constitution.md — プロジェクト最上位ルール
