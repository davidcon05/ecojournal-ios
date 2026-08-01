//
//  UITestSeedData.swift
//  EcoJournal
//
//  Codable contract decoded from the UITEST_SEED_DATA launch environment
//  variable (see EcoJournalApp.swift). Must stay structurally identical to
//  the copy in EcoJournalUITests/Base/UITestSeedData.swift — the app and
//  test targets are separate processes and communicate only via this JSON
//  shape, not shared Swift types.
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
