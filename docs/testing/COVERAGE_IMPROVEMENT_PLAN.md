# Coverage Improvement Plan

Measured 2026-07-31. Scope: `EcoJournal.app` target only (test-bundle code excluded).

## Current State

| Suite | App Coverage | Lines |
|---|---|---|
| Unit tests only (`EcoJournalTests`) — baseline | 7.13% | 1,104 / 15,475 |
| **Unit tests only — after Phase 1 + 2** | **9.58%** | **1,487 / 15,520** |
| UI tests only (`EcoJournalUITests`) | 21.12% | 3,269 / 15,475 |
| Combined (unit + UI) — original baseline | 24.36% | 3,769 / 15,475 |
| **Combined (unit + UI) — measured after Phase 2** | **26.54%** | **4,107 / 15,476** |

Unit suite: **93 tests, 0 failing** (plus 32 integration tests excluded from the
coverage run).

Two caveats on the combined figure:

- It was measured *after* Phase 2 but *before* the Phase 1 audio seams landed,
  so it does not include those gains.
- It rose +338 lines while unit-only rose +177 over the same span. The excess is
  not from unit tests — it is almost certainly the working-tree fixes to
  `DashboardView.swift` (a `.contentShape` that makes dashboard cards tappable)
  and `BaseRobot.swift`, which let the UI tests reach further into the app than
  they did when the 24.36% baseline was taken.

The combined number is *not* 7.13% + 21.12% — that would double-count lines both suites happen to touch. 24.36% is the real measured union, run through Xcode's own coverage engine in a single test pass covering both bundles at once.

**The 85%+ figure currently on the blog's EcoJournal project page is stale — real combined coverage is 24.36%.** Leaving as-is until this plan moves the real number closer, then updating the blog to match.

### Why unit and UI coverage don't overlap much

- `EcoJournalTests.xctest` itself is 94.71% covered (the tests almost all run) — but that's a different denominator, not app coverage.
- Unit tests only exercise what they directly call: 3 ViewModels + a handful of services.
- UI tests exercise real user flows end-to-end, so they're the only thing currently touching most View code at all.

## Where the Gap Actually Lives

The 3 existing ViewModels (`CreateJournalViewModel`, `DashboardViewModel`, `NewLogViewModel`) already have test files. The real gap is elsewhere:

**Services with no protocol abstraction — 100% untested (~480 lines, quick wins):**

| File | Lines | Coverage |
|---|---|---|
| `AudioRecorderService.swift` | 257 | 0% |
| `AudioTranscriptionService.swift` | 224 | 0% |

Compare to `WeatherService`/`AirQualityService`/`PhotoStorageService`, which already wrap their dependencies behind a protocol (`URLSessionProtocol`, etc.) and sit at 70-90% coverage as a direct result.

**An existing test file that isn't pulling its weight:**

| File | Lines | Coverage |
|---|---|---|
| `NewLogViewModel.swift` | 322 | 20.19% (65/322) despite having `NewLogViewModelTests.swift` |

**Business logic embedded directly in Views instead of ViewModels (the bulk of the gap):**

| File | Lines | Coverage |
|---|---|---|
| `LogDetailView.swift` | 1,500 | 0% |
| `EditLogView.swift` | 1,006 | 0% |
| `MapView.swift` | 1,407 | 0% |
| `LogsListView.swift` | 1,311 | 0% |
| `AudioMemoView.swift` | 1,178 | 0% |
| `HeroPhotoSection.swift` | 1,006 | 0% |
| `MultiAudioMemoView.swift` | 672 | 0% |
| `JournalSettingsSheet.swift` | 596 | 0% |
| `PhotoGalleryView.swift` | 570 | 0% |

Not all of this is equally worth chasing — a lot of it is declarative SwiftUI body markup, which is naturally covered by UI tests exercising the screen, not unit tests. `LogDetailView` and `EditLogView` are the priority because they carry real business logic (save/delete, GPS refresh, weather fetch — including the weather-retry feature added this session) directly in the View, not presentational layout.

## Improvement Plan

### Phase 1 — Fakes for untested services (fast, low-risk) — ✅ DONE
Protocol seams added, fakes written, Swift Testing suites in place:

| File | Before | After |
|---|---|---|
| `AudioRecorderService.swift` | 0% | **76.17%** (195/256) |
| `AudioTranscriptionService.swift` | 0% | **44.98%** (103/229) |

**`AudioEngine.swift`** seams `AVAudioRecorder` / `AVAudioPlayer` /
`AVAudioSession` behind `AudioRecording` / `AudioPlaying` /
`AudioSessionControlling`, created via an injectable `AudioEngine`.
`AudioRecorderService`'s public API is unchanged — the default arguments build
the real system objects, so no view needed touching. Record and playback are
now fully testable without a mic.

**`SpeechAuthorization.swift`** seams the availability and authorization checks
behind `SpeechAuthorizing`, which is what made `transcribe()`'s guards
untestable before (calling it raised a real permission dialog).

Why `AudioTranscriptionService` stops at ~45%: the uncovered remainder is the
recognition task itself. Faking it would mean fabricating an
`SFSpeechRecognitionResult` — which has no usable initializer — and a double
that returned no task would leave the `withCheckedThrowingContinuation` in
`transcribe()` waiting forever, hanging the suite. That path stays on
manual/device testing by design, not by omission.

`AudioEngine.swift` and `SpeechAuthorization.swift` themselves show 0% under
unit tests: they are the thin adapters that only run in the real app, where the
UI tests exercise them. That is expected and not a gap to chase.

### Phase 2 — Fix the `NewLogViewModel` gap — ✅ DONE
`NewLogViewModel.swift` went from **20.19% → 94.43%** (305/323).

The gap was never missing edge cases — the old file simply skipped `saveLog()`
and the whole weather path, with a comment claiming they caused "race
conditions in unit tests". They don't; see the harness notes below for what was
actually going wrong. `NewLogViewModelSwiftTestingTests.swift` now covers the
weather fetch/retry/timeout paths and the `saveLog()` success paths (GPS
present/absent, audio memos, journal touch).

### Phase 3 — Extract logic from `LogDetailView` and `EditLogView` — ✅ DONE
Pull business logic (weather fetch/retry, GPS refresh, save/delete) out into ViewModels. This is the largest lever — both files are 0% today and carry real logic, not just layout.

| New file | Extracted from |
|---|---|
| `EditLogViewModel.swift` | draft state, `hasUnsavedChanges`, GPS refresh, weather refresh, save, delete, photo soft-delete/restore |
| `LogDetailViewModel.swift` | weather retry, delete confirmation, audio playback toggling, AQI mapping |
| `Shared/Utilities/Timeout.swift` | `withTimeout` + timeout error — each view carried its own private copy |

Both views now follow the `NewLogView` pattern: a thin wrapper that builds the
view model once `modelContext` is available, plus a `…ContentView` holding it as
`@ObservedObject`. The split is required — handing the view model to a plain
function does not establish observation, so `@Published` changes would not
re-render.

**Behaviour changes worth knowing (not pure moves):**

- **Dismissal is indirect.** The views used to call `dismiss()` from inside
  `deleteLog()` / `saveChanges()`. A view model cannot dismiss, so it publishes
  `shouldDismiss` and the view reacts via `onChange`.
- **`shareLog()` / `exportLog()` were deleted.** Both were `print()`-only TODO
  stubs with no callers.
- **Re-entrancy guards added.** `refreshGPSCoordinates()` and
  `fetchWeatherForLog()` now no-op while already running, matching
  `NewLogViewModel.fetchWeatherIfNeeded`.
- **GPS polling is injectable** (`gpsPollInterval`, `gpsMaxAttempts`) so tests
  don't sit through the real 10-second poll.

Note that most of what remains in these two files is declarative SwiftUI body
markup, which unit tests do not execute. The extracted logic was the part worth
chasing; the view bodies stay the UI tests' job.

### Phase 4 — Close the gap with UI test scenarios — 🟡 IN PROGRESS
Re-run combined coverage. If still under 80%, the remaining gap is likely declarative View body code — close it by adding UI test scenarios for screens/states not yet exercised (empty states, error states), not more unit tests.

Confirmed by measurement: view bodies are ~60% of the remaining gap, and unit
tests will never execute them. Two files of near-identical size make the point —
`DashboardView` (13 active tests) sits at 76% with 55 of 84 functions executed,
while `LogsListView` (1 active test) sits at 6.4% with 6 of 89. Nobody asserted
harder; the difference is purely how many *states* the tests reached.

**16 UI tests were disabled, not missing.** They were commented out with a TODO
claiming they needed GPS mocking. That diagnosis was wrong. After re-enabling
them the real defects turned out to be in the test infrastructure:

1. **Element-type mismatches in screen objects.** SwiftUI decides which element
   type an `.accessibilityIdentifier` lands on, and it is frequently not the
   obvious one:
   - `Map` puts the identifier on a wrapping `Other`; the real `Map` element is
     an unidentified child. `app.maps[id]` matches nothing.
   - The metrics panel surfaces as `StaticText`, not `otherElements`.
   - `SearchBarWithDropdown` marks its container
     `.accessibilityElement(children: .contain)`, so `app.textFields[id]`
     matches nothing — the field is *inside* the identified element.

   When an element "doesn't exist" but you can see it on screen, dump
   `app.debugDescription` and read the real tree instead of guessing. `MapScreen`
   now looks elements up by identifier across all types.

2. **The seed fixture was too thin to reach most branches.** `SeedLog` carried
   only `title` and `notes`, so no fixture could satisfy
   `if !log.audioMemos.isEmpty`, `if hasGPSData`, `if let weather`, or
   `if !log.mediaURLs.isEmpty` — leaving whole sections of the detail, list, and
   map screens unreachable. It now carries coordinates, weather (with AQI),
   media URLs, and audio memos, with archetype helpers (`.bare`, `.located`,
   `.withWeather`, `.withMedia`) so tests read declaratively.

**Prefer seeding over UI-driven setup.** Building state by driving the New Log
screen depends on live GPS and weather that the simulator does not reliably
provide — the original source of the flakiness. Seed the precondition, then test
the behaviour. The exception is a test whose subject *is* the creation flow.

**Coverage comes from execution, not assertions.** An `XCTAssert` runs test code,
not app code; identifiers only let you *find* an element. What moves the number
is reaching a screen, reaching each conditional state within it, and triggering
each action closure. Vary the shape of the seeded data to unlock the branches.

## Test Harness Notes

Four things bit us while getting the new suites green. All are worth knowing
before writing more tests.

**1. `ModelContext` does not keep its `ModelContainer` alive.** This pattern
looks fine and is a landmine:

```swift
let container = try ModelContainer(for: ..., configurations: config)  // local!
testModelContext = container.mainContext                              // only this is kept
```

Once the container is released, the context and every model fetched from it
become invalid, and SwiftData traps inside *ordinary property getters* — a
plain `journal.lastModified` read crashes. Always store the container for the
lifetime of the test. This was the sole cause of a crash that looked like 16
unrelated test failures.

**2. A crash in one test fails every test that hadn't finished yet.** Swift
Testing and XCTest share one process. A trap takes the process down, and
everything still pending is reported as failed with `0.000 seconds` duration.
When a run shows a pile of unrelated failures at exactly 0.000s, look for a
single crash — the durations tell you which failures are real.

**3. Unit tests run *inside* the app.** `EcoJournalTests` sets `TEST_HOST` to
the app binary and the bundle is installed at
`EcoJournal.app/PlugIns/EcoJournalTests.xctest`. The app's `@main` and its real
SwiftData container must start up before any test runs, so a startup failure
surfaces as "Simulator device failed to launch" with every test at 0.000s.
Escaping this entirely means extracting the logic into a framework or SPM
module the tests can link directly — a structural change, not a build setting.

**4. The project defaults to `MainActor` isolation**
(`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`). An unannotated class therefore
gets an **isolated `deinit`** that traps if the instance is released off the
main queue. Singletons hide this because they never deallocate — but a
per-test fake subclass does, and it crashes. `PhotoStorageService` is now
explicitly `nonisolated` for this reason. Watch for it with any other service
a test allocates and releases.

### Test doubles

`EcoJournalTests/Mocks/` now holds:

| Double | Kind | Purpose |
|---|---|---|
| `FakeLocationManager` | subclass | Overrides everything that reaches CoreLocation; `simulateLocation(...)` stages a fix without delegate callbacks |
| `MockWeatherService` / `MockAirQualityService` | subclass | Canned data, failure, or a hang for exercising timeouts |
| `FakePhotoStorageService` | subclass | In-memory photos; keeps tests off `PhotoStorageService.shared` and off disk |
| `MockKeychainManager` / `MockPhotoStorageService` | standalone | Pre-existing; used to test those contracts directly |

Suites are **not** `.serialized` — each test builds its own container and its
own fakes, so they are genuinely independent and pass under parallel execution.
If a suite only passes when serialized, that's shared state to fix, not to
paper over.

## Re-Measuring Coverage

Unit-only coverage already has a script: `./scripts/coverage-report.sh` (see the Code Coverage section in `TESTING_STRATEGY.md`).

Combined unit+UI coverage doesn't have a permanent command yet — this measurement required a scratch test plan (`EcoJournalCombinedCoverage.xctestplan`) temporarily registered in the shared scheme, then reverted, since `xcodebuild -only-testing:` can't span two independently-configured test plans in one invocation. If we want to track the combined number over time (recommended, given it's the only real number), the next step is making that test plan and scheme registration permanent instead of scratch work, and extending `coverage-report.sh` to run it.
