# EcoJournal

iOS field journal app for environmental science fieldwork. Built as an AI-assisted learning project.

## 🔋 Offline-First Design

Eco Journal is designed to work **100% offline in remote field locations**. GPS uses satellites (not internet), and all data is stored locally.

### What Works Offline

✅ **GPS Tracking** (satellite-based, no internet needed)

✅ **Photos & Videos** (device camera, local storage)

✅ **Audio Recording + Transcription** (on-device speech-to-text)

✅ **Notes & Data Entry** (all local)

✅ **Map View** (cached tiles)

✅ **All Data Storage** (SwiftData/SQLite)

⚠️ **Optional Internet Features** (graceful degradation):
- Weather data → Shows retry button if offline
- Air quality data → Shows retry button if offline

**See:** [Offline-First Architecture](docs/architecture/offline-first-design.md) for full details

## Quick Overview

| Aspect | Details |
|--------|---------|
| **Purpose** | GPS-tagged field observations with photos, notes, and auto-weather logging |
| **User** | Environmental scientist working outdoors (often in remote locations) |
| **Platform** | iOS 17+ (iPhone only) |
| **Tech Stack** | SwiftUI, SwiftData, CoreLocation, OpenWeatherMap API, Speech framework |
| **Network** | Offline-first (internet enhances but is never required) |

## Current Status

**v1.0 MVP - 100% Complete - Ready for Device Testing! 🚀**

| Feature | Status |
|---------|--------|
| Project structure | ✅ Complete |
| Documentation | ✅ Complete |
| SwiftData models | ✅ Complete (Journal, Log, Weather) |
| Design system | ✅ Complete (colors, fonts, Theme.swift) |
| Dashboard screen | ✅ Complete (with modern card UI) |
| Password protection | ✅ Complete (Keychain + biometric auth) |
| Brute force protection | ✅ Complete (5 attempts, 5-min lockout) |
| Unit tests | ✅ Complete (43 tests across ViewModels + Services) |
| **Bottom navigation** | ✅ Complete |
| **Location services** | ✅ Complete (CoreLocation GPS tracking) |
| **Weather API** | ✅ Complete (OpenWeatherMap + AQI) |
| **New Log Entry screen** | ✅ Complete (Bento layout, GPS, weather, placeholders) |
| **Logs List View** | ✅ Complete (Featured + compact card variants) |
| **MapView** | ✅ Complete (Custom pins, callouts, live metrics) |
| **Log Editing** | ✅ Complete (includes audio memo editing) |
| **Camera Integration** | ✅ Complete (multiple photos, camera + library import) |
| **Audio Recording + Transcription** | ✅ Complete (multiple memos, transcription, playback) |

## Quick Start

```bash
# Clone the repo
git clone <repo-url>
cd EcoJournal

# Open in Xcode
open EcoJournal.xcodeproj

# Build and run
⌘R
```

### Weather API Setup (Later)
1. Sign up at [OpenWeatherMap](https://openweathermap.org/api)
2. Create `EcoJournal/Resources/Config.xcconfig`
3. Add: `WEATHER_API_KEY = your_key_here`
4. **Never commit** (already in .gitignore)

## Documentation

### Planning & Architecture
| Doc | Purpose |
|-----|---------|
| [implementation-plan.md](docs/planning/implementation-plan.md) | Detailed roadmap, API specs, code examples, v1.0 progress |
| [architecture.md](docs/planning/architecture.md) | File structure, tab names, design decisions |
| [offline-first-design.md](docs/architecture/offline-first-design.md) | **How app works 100% offline, GPS without internet** |
| [mapview-implementation-plan.md](docs/planning/mapview-implementation-plan.md) | MapView implementation details (completed) |

### Features & Security
| Doc | Purpose |
|-----|---------|
| [future-features.md](docs/future-features.md) | Remaining v1.0 features, future roadmap |
| [security-implementation.md](docs/security-implementation.md) | Password protection, biometric auth, security details |
| [design-system.md](docs/design-system.md) | Colors, typography, spacing, components |

### Testing & Distribution
| Doc | Purpose |
|-----|---------|
| [device-test-plan.md](docs/testing/device-test-plan.md) | Physical device testing checklist (critical for v1.0) |
| [TESTFLIGHT_GUIDE.md](docs/setup/TESTFLIGHT_GUIDE.md) | TestFlight setup, FREE alternatives, $99/year vs. free |

### Learning
| Doc | Purpose |
|-----|---------|
| [ai-assisted-dev.md](docs/learning/ai-assisted-dev.md) | Learnings, Xcode conventions, mistakes made |

## Tech Stack

- **UI:** SwiftUI
- **Data:** SwiftData (offline-first)
- **Location:** CoreLocation
- **Weather:** OpenWeatherMap API
- **Maps:** MapKit

## Key Conventions

- **Journal** = Top-level container (e.g., "Soil Samples 2026")
- **Log/Entry** = Individual field observation
- **Tabs:** Logs, New Log, Map
- **Always create files in Xcode** (not Finder)

## Roadmap

| Version | Focus | Timeline |
|---------|-------|----------|
| **v1.0** | GPS, weather, photos, notes, offline | 4-6 weeks |
| **v1.5** | Land navigation (navigate to logged locations) | 2 weeks |
| **v2.0** | Enhanced camera, photo overlays | 3-4 weeks |
| **v3.0** | ARKit measurements, CoreML species ID | 4-6 weeks |

## License

Personal learning project - not for commercial use.

---

## Recent Accomplishments

**Multiple Audio Memos with Transcription** - Completed 2026-05-19
- ✅ AudioMemo model with relationship to Log (multiple memos per entry)
- ✅ MultiAudioMemoView component with full functionality
- ✅ Recording with animated UI and live timer
- ✅ Automatic speech-to-text transcription (Apple Speech framework)
- ✅ Individual playback controls for each memo
- ✅ Title prompting and deletion with confirmation
- ✅ Integrated into both NewLogView and EditLogView
- ✅ Searchable transcriptions in LogsListView
- ✅ Display in LogDetailView with AudioMemoCard components

**MapView with Custom Pins & Callouts** - Completed 2026-05-13
- ✅ SwiftUI Map with hybrid style (permanent, optimized for field visibility)
- ✅ Custom colored pins (blue=weather, green=photos, purple=audio, red=basic, orange=selected)
- ✅ Custom callout with image preview, notes, date, Details button
- ✅ Collapsible live metrics panel (average elevation, humidity, temp in Fahrenheit)
- ✅ Orange center location button (bottom-right, stands out on hybrid map)
- ✅ Pin tap toggles callout (tap again or close button to dismiss)
- ✅ Visual connection line from selected pin to callout
- ✅ Empty state for journals without GPS logs
- ✅ Test data with actual asset images (placeholder-field-1, placeholder-field-2)

**Comprehensive Documentation** - Completed 2026-05-13
- ✅ [Offline-First Architecture Guide](docs/architecture/offline-first-design.md) - Clarifies GPS works via satellites, not internet
- ✅ [Physical Device Test Plan](docs/testing/device-test-plan.md) - Critical path testing for v1.0 launch
- ✅ [TestFlight Distribution Guide](docs/setup/TESTFLIGHT_GUIDE.md) - FREE alternatives vs. $99/year Apple Developer Program
- ✅ Updated all docs to reflect MapView completion (~80% of v1.0 MVP complete)

**Password Protection & Security** - Completed 2026-05-09
- ✅ KeychainManager with SHA256 password hashing + unique salt
- ✅ Biometric authentication (Face ID/Touch ID) with password fallback
- ✅ Brute force protection (5 attempts, 5-minute lockout)
- ✅ 43 comprehensive unit tests (DashboardViewModel + KeychainManager)

**Last Updated:** 2026-05-20
**Next Milestone:** Physical Device Testing → TestFlight Beta → v1.0 Launch → v1.5 Navigation
**Status:** v1.0 MVP is 100% complete - all features implemented, ready for device validation

## Planned Features

**Land Navigation (v1.5)** - Planning Complete 2026-05-20
- 🎯 Military-style land navigation for backcountry field work
- 📍 Navigate to previously logged GPS locations
- 📍 Drop custom waypoint pins for future navigation
- 📏 Real-time distance tracking as you walk
- 🔇 Audio callouts for screen-off navigation (phone in pocket)
- 🔋 Background GPS tracking with 6-10% battery/hour (screen off)
- 🗺️ Breadcrumb trail showing path taken
- 🧭 Bearing indicator with compass arrow
- 📖 Full spike documentation: [navigation-feature-spike.md](docs/research/navigation-feature-spike.md)
- ⏱️ Est: 2 days implementation + 1 day testing per phase
