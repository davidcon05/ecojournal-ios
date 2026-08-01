# Testing Strategy

This document outlines our testing approach for EcoJournal, including unit tests, integration tests, and UI test data strategies.

## Test Categories

### Unit Tests (Fast, Mocked)
- **Purpose**: Test business logic in isolation
- **Characteristics**:
  - Use mocks/stubs for external dependencies
  - Run in milliseconds
  - Run on every commit (pre-push hook)
  - No side effects (no disk, network, or keychain access)

### Integration Tests (Slower, Real Services)
- **Purpose**: Verify critical interactions with system APIs
- **Characteristics**:
  - Use real iOS Keychain, file system, or other system services
  - Run slower (seconds)
  - May have side effects
  - Run manually or in CI only (skipped in pre-push hook)

### UI Tests (Slowest, End-to-End)
- **Purpose**: Test user workflows
- **Characteristics**:
  - Launch full app
  - Simulate user interactions
  - Run slowest (minutes)
  - Run manually or nightly in CI

---

## Current Test Distribution

| Test Suite | Total Tests | Type | Uses Real Services? | Runs in Pre-Push? |
|------------|-------------|------|---------------------|-------------------|
| Models (Journal, Log, Weather) | ~74 | Unit | No | ✅ Yes |
| ViewModels | ~93 | Unit | No (uses MockKeychainManager) | ✅ Yes |
| WeatherService | ~11 | Unit | No (uses MockURLSession) | ✅ Yes |
| AirQualityService | ~10 | Unit | No (uses MockURLSession) | ✅ Yes |
| **KeychainManagerUnitTests** | **~20** | **Unit** | **No (uses MockKeychainManager)** | ✅ **Yes** |
| **PhotoStorageUnitTests** | **~14** | **Unit** | **No (uses MockPhotoStorageService)** | ✅ **Yes** |
| KeychainManagerTests | ~44 | Integration | Yes (real iOS Keychain) | ❌ No (manual/CI only) |
| PhotoStorageServiceTests | ~10 | Integration | Yes (real file system) | ❌ No (manual/CI only) |

**Total: ~276 tests**
- **Fast tests (run in pre-push)**: ~222 tests (<1 minute)
- **Slow integration tests (manual/CI only)**: ~54 tests (~2 minutes)

---

## KeychainManager Testing Strategy

**Problem**: KeychainManager had 44 tests that all hit the real iOS Keychain, making the test suite slow.

**Solution**: Created separate test files for unit tests (mocked) and integration tests (real).

### Implementation ✅ COMPLETED

**Integration Tests** (`KeychainManagerTests.swift` - 44 tests):
- Uses real `KeychainManager()` instance
- Hits actual iOS Keychain APIs
- Verifies integration with iOS system services
- **Skipped in pre-push** to keep it fast
- Run manually or in CI before releases

**Unit Tests** (`KeychainManagerUnitTests.swift` - ~20 tests):
- Uses `MockKeychainManager`
- Tests business logic in isolation
- Covers edge cases and error handling:
  - Password hashing/verification
  - Salt generation
  - Case sensitivity
  - Special characters (unicode, emojis)
  - Error conditions
  - Biometric mocking
- **Runs in pre-push** (fast, no simulator overhead)

**MockKeychainManager** now mimics real hashing logic:
- Generates SHA256 hash with random salt
- Stores in "hash|salt" format
- Uses constant-time comparison
- Identical behavior to real implementation

**Benefits**:
- Pre-push tests run 100x faster (~20 tests in milliseconds vs 44 tests in minutes)
- No keychain state contamination
- Easy error condition testing
- Still have confidence from integration tests (run manually/CI)

---

## PhotoStorageService Testing Strategy

**Problem**: PhotoStorageService had 10 tests that all hit the real file system, requiring simulator overhead.

**Solution**: Created separate test files for unit tests (mocked) and integration tests (real).

### Implementation ✅ COMPLETED

**Integration Tests** (`PhotoStorageServiceTests.swift` - 10 tests):
- Uses real `PhotoStorageService()` instance
- Writes/reads/deletes actual files on simulator disk
- Verifies integration with FileManager APIs
- **Skipped in pre-push** to keep it fast
- Run manually or in CI before releases

**Unit Tests** (`PhotoStorageUnitTests.swift` - ~14 tests):
- Uses `MockPhotoStorageService`
- Tests business logic in isolation
- Covers edge cases and error handling:
  - Unique filename generation
  - Save/load/delete flows
  - Invalid URL handling
  - Error conditions
  - Batch deletion
- **Runs in pre-push** (fast, no file I/O overhead)

**MockPhotoStorageService** mimics real file operations:
- Stores images in memory (URL → UIImage dictionary)
- Generates unique UUIDs for filenames
- Returns nil on failure conditions
- No actual disk I/O required

**Benefits**:
- Pre-push tests run instantly (~14 tests in milliseconds vs 10 tests in seconds)
- No file system side effects
- Easy error condition testing
- Deterministic test data

---

## Fake Data for UI Tests

**Goal**: Create realistic test data for UI testing and screenshots.

### Why Fake Data Matters

1. **Consistent UI Tests**: Same data = reproducible tests
2. **Beautiful Screenshots**: Well-crafted data for App Store
3. **Developer Experience**: Populated app on first launch
4. **Demo Mode**: Show potential features

### Fake Data Strategy

#### Option 1: Test Fixtures (Recommended)
Create JSON fixtures that can be loaded into SwiftData:

```swift
// Tests/Fixtures/sample-journals.json
[
  {
    "id": "fixture-1",
    "name": "Backyard Birds 🦅",
    "theme": "forest",
    "logs": [
      {
        "title": "Red-tailed Hawk Sighting",
        "notes": "Spotted perched on oak tree, 3:45 PM",
        "timestamp": "2025-05-15T15:45:00Z",
        "latitude": 47.6062,
        "longitude": -122.3321,
        "weather": {
          "condition": "Partly Cloudy",
          "temperature": 18.5
        },
        "photoURLs": ["sample-hawk-1.jpg"]
      }
    ]
  }
]
```

#### Option 2: Factory Pattern
Create data factories for tests:

```swift
// Tests/Factories/JournalFactory.swift
struct JournalFactory {
    static func createSampleJournal(
        name: String = "Sample Journal",
        logCount: Int = 5
    ) -> Journal {
        let journal = Journal(name: name)

        for i in 1...logCount {
            let log = Log(
                title: "Sample Log \(i)",
                notes: "This is a sample observation",
                journal: journal
            )
            journal.logs.append(log)
        }

        return journal
    }

    static func createRichJournal() -> Journal {
        // Journal with photos, weather data, locations, etc.
    }
}
```

#### Option 3: Debug Data Injection
Add a debug menu to inject test data:

```swift
#if DEBUG
struct DebugDataInjector {
    static func injectSampleData(into context: ModelContext) {
        // Create 3 journals with various themes
        // Add 10-15 logs per journal
        // Include photos, weather, locations
        // Mix of recent and old entries
    }
}
#endif
```

### Recommended Approach

**For Unit Tests**: Use factories (fast, customizable)
**For UI Tests**: Use fixtures + factories (consistent data)
**For Development**: Debug injection (one-time setup)
**For App Store Screenshots**: Hand-crafted fixtures with beautiful photos

### Sample Data Content Ideas

**Journals**:
- "Backyard Birds 🦅" (10 entries, forest theme)
- "Hiking Trails 🥾" (15 entries, mountain theme)
- "Garden Progress 🌱" (20 entries, meadow theme)

**Logs** should include:
- ✅ Titles (specific species/observations)
- ✅ Detailed notes (2-3 sentences)
- ✅ GPS coordinates (varied locations)
- ✅ Weather data (different conditions)
- ✅ Photos (nature photography)
- ✅ Timestamps (spread over weeks/months)
- ✅ Mix of morning/afternoon/evening entries

### Implementation TODO

- [ ] Create `Tests/Fixtures/` directory
- [ ] Add sample JSON fixtures
- [ ] Create `Tests/Factories/` directory
- [ ] Implement factory patterns
- [ ] Add debug data injection menu
- [ ] Source sample nature photos (royalty-free)
- [ ] Document fixture usage in test setup

---

## Running Tests

### All Tests (Full Suite - ~210 tests, 3-5 minutes)
```bash
xcodebuild test -scheme EcoJournal -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

### Fast Unit Tests Only (~222 tests, <1 minute)
```bash
# Skip slow integration tests - this is what pre-push runs
xcodebuild test \
  -scheme EcoJournal \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:EcoJournalTests \
  -skip-testing:EcoJournalTests/KeychainManagerTests \
  -skip-testing:EcoJournalTests/PhotoStorageServiceTests
```

**Includes**:
- All model tests (~74)
- All ViewModel tests (~93)
- All service tests (~45)
- **KeychainManagerUnitTests** (~20) - mocked, fast
- **PhotoStorageUnitTests** (~14) - mocked, fast

**Excludes**:
- KeychainManagerTests (44) - integration, slow
- PhotoStorageServiceTests (10) - integration, slow

### Integration Tests Only (~54 tests, ~2 minutes)
```bash
# Only run slow integration tests with real iOS APIs
xcodebuild test \
  -scheme EcoJournal \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:EcoJournalTests/KeychainManagerTests \
  -only-testing:EcoJournalTests/PhotoStorageServiceTests
```

**When to run**:
- Before major releases
- Before submitting to TestFlight/App Store
- When modifying KeychainManager or PhotoStorageService
- In CI/CD pipeline

### Just Mocked Unit Tests (~34 tests, <5 seconds)
```bash
# Ultra-fast mocked tests only
xcodebuild test \
  -scheme EcoJournal \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:EcoJournalTests/KeychainManagerUnitTests \
  -only-testing:EcoJournalTests/PhotoStorageUnitTests
```

### Specific Test Suite
```bash
xcodebuild test -scheme EcoJournal -only-testing:EcoJournalTests/WeatherServiceTests
```

### Pre-Push Hook
Automatically runs on `git push`:
- Builds the project
- Runs fast unit tests (~140 tests, <1 minute)
- **Skips slow integration tests** (KeychainManagerTests, PhotoStorageServiceTests)
- Blocks push if tests fail

Location: `.git/hooks/pre-push`

**Note**: Integration tests are skipped in pre-push to keep it fast. Run full test suite manually before major releases.

---

## Best Practices

### When Writing Tests

1. **Mock external dependencies** (network, disk, keychain)
2. **Use descriptive test names** - explains what's being tested
3. **Follow Arrange-Act-Assert** pattern
4. **One assertion per test** (generally)
5. **Clean up side effects** (keychain, files)

### When to Use Integration Tests

Only when testing:
- Real keychain interactions
- File system operations
- System framework behavior
- Security-critical code paths

### When to Use Mocks

When testing:
- Business logic
- View model state changes
- Error handling
- Edge cases
- Algorithm correctness

---

---

## Code Coverage

### How Coverage Is Scoped

Coverage is measured for the **EcoJournal app target only**. The Xcode scheme's
`<TestAction>` element sets `codeCoverageEnabled = "YES"` and lists a single
`<CodeCoverageTargets>` entry pointing at the `EcoJournal` target
(BlueprintIdentifier `01ACAB1E2FAA7C9D002C45CC`).

This means:
- `EcoJournalTests` code (test helpers, mocks, fixtures) is **excluded** from
  the coverage numbers.
- `EcoJournalUITests` code is **excluded** too.
- Only production app code contributes to the percentage, so the numbers
  accurately reflect how well the app is tested.

### Generating a Coverage Report

Use the script at `scripts/coverage-report.sh`. It requires no Ruby gems, no
Fastlane, and no extra package-manager dependencies — only standard Xcode
command-line tools (`xcodebuild`, `xcrun xccov`) and Python 3.

```bash
# From the project root:
./scripts/coverage-report.sh

# Open the HTML report in your browser immediately when done:
./scripts/coverage-report.sh --open
```

**What it does:**
1. Runs `EcoJournalTests` only (skips UITests and slow integration tests) with
   coverage enabled, on the simulator named by `DESTINATION` in the script
   (currently iPhone 17 Pro). Override it with `ECOJOURNAL_DESTINATION` if you
   have a different set of simulators installed — a bare `name=` is resolved
   against the *latest* installed runtime, so a device that only exists on an
   older runtime will fail to resolve.
2. Saves the raw results to `./coverage/results.xcresult`.
3. Exports a JSON report  → `./coverage/coverage.json`
4. Exports a text summary → `./coverage/coverage.txt`
5. Generates a standalone HTML report → `./coverage/index.html`

The HTML report is generated by a small inline Python 3 script that reads the
JSON output from `xcrun xccov` — no additional tools needed.

### Output Location

All output lands in `./coverage/` at the project root. This directory is
**gitignored** and safe to delete at any time.

```
coverage/
  results.xcresult/   ← raw Xcode result bundle
  coverage.json       ← full per-line JSON data
  coverage.txt        ← human-readable text summary
  index.html          ← standalone HTML report (open in browser)
```

The text summary is also printed to the terminal at the end of the script run.

### Notes for Xcode Cloud

Xcode Cloud automatically collects coverage data when you open the scheme in
Xcode (the `codeCoverageEnabled` flag is already in the shared scheme). You can
inspect per-target coverage in the Xcode Cloud build report. The
`coverage-report.sh` script is primarily for local development workflows.

---

## Future Improvements

- [ ] Add UI test suite for critical flows
- [ ] Implement snapshot testing for views
- [ ] Add performance benchmarks
- [x] **Create test coverage reports** ✅ (Completed 2026-07-22)
- [ ] Automate screenshot generation for App Store
- [x] **Optimize test suite with mocked unit tests** ✅ (Completed 2026-05-29)

---

## Resources

- [Testing Documentation](https://developer.apple.com/documentation/xcode/testing-your-apps-in-xcode)
- [Swift Testing Framework](https://developer.apple.com/documentation/testing)
- [Writing Testable Code](https://developer.apple.com/videos/play/wwdc2023/10175/)
