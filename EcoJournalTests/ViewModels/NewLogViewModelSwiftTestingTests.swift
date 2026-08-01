//
//  NewLogViewModelSwiftTestingTests.swift
//  EcoJournalTests
//
//  Weather fetch, retry, and saveLog() success-path coverage for
//  NewLogViewModel, written with Swift Testing. Reuses MockWeatherService /
//  MockAirQualityService from NewLogViewModelTests.swift.
//

import Testing
import CoreLocation
import SwiftData
@testable import EcoJournal

@MainActor
@Suite("NewLogViewModel Weather & Save Tests")
struct NewLogViewModelSwiftTestingTests {
    /// Held strongly for the lifetime of each test. `ModelContext` alone does
    /// not keep its container alive, and once the container goes the context
    /// and every model fetched from it become invalid — SwiftData then traps
    /// inside ordinary property getters.
    let testContainer: ModelContainer
    let testJournal: Journal
    let testModelContext: ModelContext
    let mockLocationManager: FakeLocationManager
    let mockWeatherService: MockWeatherService
    let mockAirQualityService: MockAirQualityService
    let fakePhotoStorage: FakePhotoStorageService
    let sut: NewLogViewModel

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        testContainer = try ModelContainer(for: Journal.self, Log.self, AudioMemo.self, configurations: config)
        testModelContext = testContainer.mainContext

        testJournal = Journal(name: "Test Journal")
        testModelContext.insert(testJournal)
        try testModelContext.save()

        mockLocationManager = FakeLocationManager()
        mockWeatherService = MockWeatherService()
        mockAirQualityService = MockAirQualityService()
        fakePhotoStorage = FakePhotoStorageService()

        sut = NewLogViewModel(
            journal: testJournal,
            modelContext: testModelContext,
            locationManager: mockLocationManager,
            weatherService: mockWeatherService,
            airQualityService: mockAirQualityService,
            photoStorage: fakePhotoStorage
        )
    }

    // MARK: - Weather Fetch Guard Tests

    @Test("fetchWeatherIfNeeded does not fetch when weather is already set")
    func fetchWeatherIfNeeded_whenWeatherAlreadySet_doesNotFetch() {
        sut.currentWeather = Weather(condition: "Clear", temperature: 70, humidity: 40, windSpeed: 3, icon: "01d")

        sut.fetchWeatherIfNeeded(for: CLLocation(latitude: 47.6062, longitude: -122.3321))

        #expect(mockWeatherService.fetchWeatherCalled == false)
    }

    @Test("fetchWeatherIfNeeded does not fetch when already loading")
    func fetchWeatherIfNeeded_whenAlreadyLoading_doesNotFetch() {
        sut.isLoadingWeather = true

        sut.fetchWeatherIfNeeded(for: CLLocation(latitude: 47.6062, longitude: -122.3321))

        #expect(mockWeatherService.fetchWeatherCalled == false)
    }

    // MARK: - Weather Fetch Outcome Tests

    @Test("fetchWeatherIfNeeded on success sets combined weather and air quality data")
    func fetchWeatherIfNeeded_onSuccess_setsCombinedWeatherData() async throws {
        sut.fetchWeatherIfNeeded(for: CLLocation(latitude: 47.6062, longitude: -122.3321))
        try await waitUntil { sut.currentWeather != nil || sut.weatherError != nil }

        #expect(sut.currentWeather?.condition == "Clear")
        #expect(sut.currentWeather?.aqi == 2)
        #expect(sut.currentWeather?.pm25 == 12.5)
        #expect(sut.isLoadingWeather == false)
        #expect(sut.weatherError == nil)
    }

    @Test("fetchWeatherIfNeeded sets weatherError when the weather service fails")
    func fetchWeatherIfNeeded_whenWeatherServiceFails_setsWeatherError() async throws {
        mockWeatherService.shouldSucceed = false

        sut.fetchWeatherIfNeeded(for: CLLocation(latitude: 47.6062, longitude: -122.3321))
        try await waitUntil { sut.weatherError != nil }

        #expect(sut.weatherError != nil)
        #expect(sut.currentWeather == nil)
        #expect(sut.isLoadingWeather == false)
    }

    @Test("fetchWeatherIfNeeded sets a timeout error when the fetch exceeds the configured timeout")
    func fetchWeatherIfNeeded_whenFetchExceedsTimeout_setsTimeoutError() async throws {
        mockWeatherService.shouldHang = true
        let fastTimeoutSut = NewLogViewModel(
            journal: testJournal,
            modelContext: testModelContext,
            locationManager: mockLocationManager,
            weatherService: mockWeatherService,
            airQualityService: mockAirQualityService,
            photoStorage: fakePhotoStorage,
            weatherFetchTimeoutSeconds: 0.05
        )

        fastTimeoutSut.fetchWeatherIfNeeded(for: CLLocation(latitude: 47.6062, longitude: -122.3321))
        try await waitUntil { fastTimeoutSut.weatherError != nil }

        #expect(fastTimeoutSut.weatherError == "Weather fetch timed out")
        #expect(fastTimeoutSut.currentWeather == nil)
    }

    // MARK: - Retry Weather Tests

    @Test("retryWeatherFetch does nothing when there is no location")
    func retryWeatherFetch_withNoLocation_doesNothing() {
        mockLocationManager.location = nil

        sut.retryWeatherFetch()

        #expect(mockWeatherService.fetchWeatherCalled == false)
    }

    @Test("retryWeatherFetch resets stale state and refetches when a location is available")
    func retryWeatherFetch_withLocation_resetsAndRefetches() async throws {
        sut.currentWeather = Weather(condition: "Stale", temperature: 0, humidity: 0, windSpeed: 0, icon: "01d")
        sut.weatherError = "Old error"
        mockLocationManager.simulateLocation(latitude: 47.6062, longitude: -122.3321)

        sut.retryWeatherFetch()
        try await waitUntil { sut.currentWeather != nil }

        #expect(mockWeatherService.fetchWeatherCalled == true)
        #expect(sut.currentWeather?.condition == "Clear")
        #expect(sut.weatherError == nil)
    }

    // MARK: - Save Logic Tests

    @Test("saveLog attaches GPS coordinates when a location is available")
    func saveLog_withLocation_attachesGPSCoordinates() throws {
        sut.title = "Coastal Observation"
        mockLocationManager.simulateLocation(latitude: 47.6062, longitude: -122.3321)

        sut.saveLog()

        let savedLog = try #require(try testModelContext.fetch(FetchDescriptor<Log>()).first)
        let latitude = try #require(savedLog.latitude)
        let longitude = try #require(savedLog.longitude)
        #expect(abs(latitude - 47.6062) < 0.0001)
        #expect(abs(longitude - (-122.3321)) < 0.0001)
        #expect(sut.showingSaveConfirmation == true)
    }

    @Test("saveLog leaves GPS coordinates nil when no location is available")
    func saveLog_withoutLocation_leavesGPSCoordinatesNil() throws {
        sut.title = "Indoor Observation"
        mockLocationManager.location = nil

        sut.saveLog()

        let savedLog = try #require(try testModelContext.fetch(FetchDescriptor<Log>()).first)
        #expect(savedLog.latitude == nil)
        #expect(savedLog.longitude == nil)
    }

    @Test("saveLog attaches queued audio memos to the saved log")
    func saveLog_withAudioMemos_attachesMemosToLog() throws {
        sut.title = "Field Recording"
        let memo = AudioMemo(title: "Bird call", audioURL: URL(string: "file:///memo.m4a")!, duration: 12)
        sut.audioMemos = [memo]

        sut.saveLog()

        let savedLog = try #require(try testModelContext.fetch(FetchDescriptor<Log>()).first)
        #expect(savedLog.audioMemos.count == 1)
        #expect(memo.log === savedLog)
    }

    @Test("saveLog updates the journal's lastModified timestamp")
    func saveLog_onSuccess_updatesJournalLastModified() throws {
        sut.title = "Test Entry"
        let originalTimestamp = testJournal.lastModified

        sut.saveLog()

        #expect(testJournal.lastModified != originalTimestamp)
    }

    // MARK: - Helpers

    private func waitUntil(
        timeout: TimeInterval = 2.0,
        condition: @escaping () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline {
                throw WaitTimeoutError()
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    private struct WaitTimeoutError: Error {}
}
