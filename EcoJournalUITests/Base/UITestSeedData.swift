//
//  UITestSeedData.swift
//  EcoJournalUITests
//
//  Codable contract encoded into the UITEST_SEED_DATA launch environment
//  variable, read back by EcoJournal/Testing/UITestSeedData.swift in the app
//  target. Must stay structurally identical to that copy — the app and test
//  targets are separate processes and communicate only via this JSON shape,
//  not shared Swift types.
//
//  Optional fields exist so a fixture can express the *shape* of a log, not
//  just its text. Large parts of the log screens are gated behind
//  `if log.weather != nil`, `if !log.mediaURLs.isEmpty`, `if hasGPSData`, and
//  friends, and a seed that cannot set those leaves that code unreachable.
//

import Foundation

struct SeedJournal: Codable {
    let name: String
    let isPasswordProtected: Bool
    let logs: [SeedLog]

    /// Written into the Keychain at seed time so a protected journal can
    /// actually be unlocked. Marking a journal protected is not enough on its
    /// own — the password lives in the Keychain, not in the model.
    var password: String?
}

struct SeedLog: Codable {
    let title: String
    let notes: String
    var latitude: Double?
    var longitude: Double?
    var altitude: Double?
    var weather: SeedWeather?
    var mediaURLs: [String]?
    var audioMemos: [SeedAudioMemo]?
}

struct SeedWeather: Codable {
    let condition: String
    let temperature: Double
    let humidity: Int
    let windSpeed: Double
    let icon: String
    var aqi: Int?
    var pm25: Double?
    var pm10: Double?
}

struct SeedAudioMemo: Codable {
    let title: String
    var transcription: String?
    var duration: Double
}

// MARK: - Fixture Archetypes

extension SeedLog {
    /// Title + notes only. Exercises the `else` fallbacks on every screen that
    /// branches on log content.
    static func bare(title: String, notes: String = "Plain observation") -> SeedLog {
        SeedLog(title: title, notes: notes)
    }

    /// Carries coordinates: unlocks the detail telemetry + location sections
    /// and puts a pin on the map.
    static func located(
        title: String,
        latitude: Double = 47.6062,
        longitude: Double = -122.3321
    ) -> SeedLog {
        SeedLog(
            title: title,
            notes: "Observation with coordinates",
            latitude: latitude,
            longitude: longitude,
            altitude: 50
        )
    }

    /// Coordinates + weather + AQI: unlocks the weather card and its nested
    /// air-quality branch.
    static func withWeather(title: String) -> SeedLog {
        SeedLog(
            title: title,
            notes: "Observation with weather",
            latitude: 47.6062,
            longitude: -122.3321,
            altitude: 50,
            weather: SeedWeather(
                condition: "Clear",
                temperature: 72,
                humidity: 50,
                windSpeed: 5,
                icon: "01d",
                aqi: 2,
                pm25: 12.5,
                pm10: 20
            )
        )
    }

    /// Photos + audio memos: unlocks HeroPhotoSection and the audio sections.
    static func withMedia(title: String) -> SeedLog {
        SeedLog(
            title: title,
            notes: "Observation with media",
            latitude: 47.6062,
            longitude: -122.3321,
            audioMemos: [
                SeedAudioMemo(title: "Dawn chorus", transcription: "Birds calling at sunrise", duration: 12)
            ]
        )
    }
}

extension SeedJournal {
    /// One journal whose four logs between them satisfy every content branch
    /// on the list, detail, and map screens.
    static func richFixture(name: String = "Test Journal") -> SeedJournal {
        SeedJournal(
            name: name,
            isPasswordProtected: false,
            logs: [
                .withWeather(title: "Weather Log"),
                .withMedia(title: "Media Log"),
                .located(title: "Located Log"),
                .bare(title: "Bare Log")
            ]
        )
    }

    static func empty(name: String = "Test Journal") -> SeedJournal {
        SeedJournal(name: name, isPasswordProtected: false, logs: [])
    }
}
