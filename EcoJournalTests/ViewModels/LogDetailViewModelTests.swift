//
//  LogDetailViewModelTests.swift
//  EcoJournalTests
//
//  Covers the logic extracted from LogDetailView: the weather retry for
//  entries saved without weather, delete confirmation, audio playback
//  toggling, and the AQI display mapping.
//

import Testing
import Foundation
import SwiftData
@testable import EcoJournal

@MainActor
@Suite("LogDetailViewModel Tests")
struct LogDetailViewModelTests {
    let testContainer: ModelContainer
    let testModelContext: ModelContext
    let journal: Journal
    let log: Log
    let audioEngine: FakeAudioEngine
    let audioService: AudioRecorderService
    let weatherService: MockWeatherService
    let airQualityService: MockAirQualityService
    let sut: LogDetailViewModel

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        testContainer = try ModelContainer(for: Journal.self, Log.self, AudioMemo.self, configurations: config)
        testModelContext = testContainer.mainContext

        journal = Journal(name: "Test Journal")
        testModelContext.insert(journal)

        log = Log(title: "Heron Sighting", notes: "By the water", mediaURLs: [])
        testModelContext.insert(log)
        log.journal = journal
        log.latitude = 47.6062
        log.longitude = -122.3321
        try testModelContext.save()

        audioEngine = FakeAudioEngine()
        audioService = AudioRecorderService(audioEngine: audioEngine, audioSession: FakeAudioSession())
        weatherService = MockWeatherService()
        airQualityService = MockAirQualityService()

        sut = LogDetailViewModel(
            log: log,
            modelContext: testModelContext,
            audioService: audioService,
            weatherService: weatherService,
            airQualityService: airQualityService,
            weatherFetchTimeoutSeconds: 0.5
        )
    }

    // MARK: - GPS Presence

    @Test("A log with coordinates reports GPS data")
    func hasGPSData_withCoordinates_isTrue() {
        #expect(sut.hasGPSData == true)
    }

    @Test("A log missing a longitude does not report GPS data")
    func hasGPSData_withPartialCoordinates_isFalse() {
        log.longitude = nil
        #expect(sut.hasGPSData == false)
    }

    @Test("Weather can be retried only for a located entry that has none")
    func canFetchWeather_reflectsLocationAndMissingWeather() {
        #expect(sut.canFetchWeather == true)

        log.weather = Weather(condition: "Clear", temperature: 70, humidity: 40, windSpeed: 3, icon: "01d")
        #expect(sut.canFetchWeather == false)
    }

    // MARK: - AQI Mapping

    @Test(
        "AQI values map to their display labels",
        arguments: [
            (1, "1 Good"),
            (2, "2 Fair"),
            (3, "3 Moderate"),
            (4, "4 Poor"),
            (5, "5 Very Poor")
        ]
    )
    func aqiLabel_mapsKnownValues(aqi: Int, expected: String) {
        #expect(sut.aqiLabel(aqi) == expected)
    }

    @Test("An unknown AQI value falls back to the raw number")
    func aqiLabel_withUnknownValue_returnsRawNumber() {
        #expect(sut.aqiLabel(9) == "9")
    }

    // MARK: - Weather Time Mismatch Copy

    @Test("The mismatch warning names the entry's creation time")
    func weatherTimeMismatchMessage_mentionsCreationTime() {
        let createdAt = log.timestamp.formatted(date: .abbreviated, time: .shortened)
        #expect(sut.weatherTimeMismatchMessage.contains(createdAt))
    }

    // MARK: - Weather Fetch

    @Test("fetchWeatherForLog stores combined weather and persists it")
    func fetchWeather_onSuccess_setsWeatherOnLog() async throws {
        sut.fetchWeatherForLog()
        try await waitUntil { sut.isRefreshingWeather == false }

        #expect(log.weather?.condition == "Clear")
        #expect(log.weather?.aqi == 2)
        #expect(sut.weatherRefreshError == nil)
    }

    @Test("fetchWeatherForLog does nothing without coordinates")
    func fetchWeather_withoutCoordinates_doesNothing() {
        log.latitude = nil

        sut.fetchWeatherForLog()

        #expect(sut.isRefreshingWeather == false)
        #expect(weatherService.fetchWeatherCalled == false)
    }

    @Test("fetchWeatherForLog ignores a second call while one is in flight")
    func fetchWeather_whileRefreshing_isIgnored() {
        sut.isRefreshingWeather = true

        sut.fetchWeatherForLog()

        #expect(weatherService.fetchWeatherCalled == false)
    }

    @Test("fetchWeatherForLog surfaces a service failure")
    func fetchWeather_onFailure_setsError() async throws {
        weatherService.shouldSucceed = false

        sut.fetchWeatherForLog()
        try await waitUntil { sut.weatherRefreshError != nil }

        #expect(sut.isRefreshingWeather == false)
        #expect(log.weather == nil)
    }

    @Test("fetchWeatherForLog reports a timeout distinctly")
    func fetchWeather_onTimeout_setsTimeoutError() async throws {
        weatherService.shouldHang = true

        sut.fetchWeatherForLog()
        try await waitUntil { sut.weatherRefreshError != nil }

        #expect(sut.weatherRefreshError == "Weather refresh timed out")
        #expect(log.weather == nil)
    }

    // MARK: - Delete

    @Test("deleteLog does nothing until the user types DELETE")
    func deleteLog_withoutConfirmation_doesNothing() throws {
        sut.deleteConfirmationText = "delete please"

        #expect(sut.deleteLog() == false)
        #expect(try testModelContext.fetch(FetchDescriptor<Log>()).isEmpty == false)
        #expect(sut.shouldDismiss == false)
    }

    @Test("deleteLog accepts the confirmation case-insensitively and trimmed")
    func deleteLog_withConfirmation_deletes() throws {
        sut.deleteConfirmationText = " Delete "

        #expect(sut.deleteLog() == true)
        #expect(try testModelContext.fetch(FetchDescriptor<Log>()).isEmpty)
        #expect(sut.shouldDismiss == true)
    }

    // MARK: - Audio Playback

    @Test("Tapping a memo starts it playing")
    func toggleAudio_startsPlayback() {
        let memo = AudioMemo(title: "Bird call", audioURL: URL(fileURLWithPath: "/fake/memo.m4a"), duration: 5)

        sut.toggleAudio(for: memo)

        #expect(sut.playingMemoId == memo.id)
        #expect(audioEngine.playerToReturn.playCallCount == 1)
    }

    @Test("Tapping the memo that is already playing stops it")
    func toggleAudio_onPlayingMemo_stops() {
        let memo = AudioMemo(title: "Bird call", audioURL: URL(fileURLWithPath: "/fake/memo.m4a"), duration: 5)
        sut.toggleAudio(for: memo)

        sut.toggleAudio(for: memo)

        #expect(sut.playingMemoId == nil)
    }

    @Test("Tapping a different memo switches playback to it")
    func toggleAudio_onOtherMemo_switches() {
        let first = AudioMemo(title: "One", audioURL: URL(fileURLWithPath: "/fake/one.m4a"), duration: 5)
        let second = AudioMemo(title: "Two", audioURL: URL(fileURLWithPath: "/fake/two.m4a"), duration: 5)
        sut.toggleAudio(for: first)

        sut.toggleAudio(for: second)

        #expect(sut.playingMemoId == second.id)
        #expect(audioEngine.madePlayerURLs.count == 2)
    }

    // MARK: - Helpers

    private func waitUntil(
        timeout: TimeInterval = 3.0,
        condition: @escaping () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { throw WaitTimeoutError() }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    private struct WaitTimeoutError: Error {}
}
