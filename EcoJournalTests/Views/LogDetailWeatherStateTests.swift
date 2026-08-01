//
//  LogDetailWeatherStateTests.swift
//  EcoJournalTests
//
//  LogDetailView renders its own inline telemetry grid rather than reusing
//  WeatherDataCard, so it has a separate state matrix that nothing else covers.
//
//  Only two of these five states are reachable from a UI journey — a seeded log
//  with weather and one without. Refreshing, refresh-failed, and the AQI branch
//  all require the network to behave a particular way on cue.
//

import XCTest
internal import SwiftUI
import SwiftData
import ViewInspector
@testable import EcoJournal

@MainActor
final class LogDetailWeatherStateTests: XCTestCase {

    private var container: ModelContainer!
    private var journal: Journal!
    private var log: Log!
    private var audioService: AudioRecorderService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Journal.self, Log.self, AudioMemo.self, configurations: config)

        journal = Journal(name: "Weather Journal")
        container.mainContext.insert(journal)

        log = Log(title: "Weather Log", notes: "Notes", mediaURLs: [])
        container.mainContext.insert(log)
        log.journal = journal
        log.latitude = 47.6062
        log.longitude = -122.3321
        try container.mainContext.save()

        audioService = AudioRecorderService(
            audioEngine: FakeAudioEngine(),
            audioSession: FakeAudioSession()
        )
    }

    override func tearDownWithError() throws {
        container = nil; journal = nil; log = nil; audioService = nil
        try super.tearDownWithError()
    }

    private func makeViewModel() -> LogDetailViewModel {
        LogDetailViewModel(
            log: log,
            modelContext: container.mainContext,
            audioService: audioService,
            weatherService: MockWeatherService(),
            airQualityService: MockAirQualityService()
        )
    }

    private func makeView(_ viewModel: LogDetailViewModel) -> LogDetailContentView {
        LogDetailContentView(viewModel: viewModel, journal: journal, audioService: audioService)
    }

    /// TelemetryCard renders its label via `Text(label.uppercased())`, so
    /// compare case-insensitively — these tests are about which cards appear,
    /// not how they are styled.
    private func renderedText(_ viewModel: LogDetailViewModel) throws -> String {
        try makeView(viewModel).inspect()
            .findAll(ViewType.Text.self)
            .compactMap { try? $0.string() }
            .joined(separator: " | ")
            .lowercased()
    }

    private func weather(aqi: Int? = nil) -> Weather {
        Weather(
            condition: "Clear",
            temperature: 72,
            humidity: 50,
            windSpeed: 5,
            icon: "01d",
            aqi: aqi,
            pm25: aqi != nil ? 12.5 : nil,
            pm10: nil
        )
    }

    // MARK: - State 1: weather present, no AQI

    func test_withWeather_showsTemperatureHumidityAndWind() throws {
        log.weather = weather()

        let text = try renderedText(makeViewModel())

        XCTAssertTrue(text.contains("temp"), "got: \(text)")
        XCTAssertTrue(text.contains("humidity"), "got: \(text)")
        XCTAssertTrue(text.contains("wind"), "got: \(text)")
        XCTAssertFalse(text.contains("air quality"), "AQI must not render without an AQI value")
    }

    /// This screen used to render wind in mph while every other screen showed
    /// m/s, for the same log. One shared card means one unit.
    func test_withWeather_showsWindInTheSharedUnit() throws {
        log.weather = weather()   // 5 m/s

        let text = try renderedText(makeViewModel())

        XCTAssertTrue(text.contains("5.0 m/s"), "Wind should match the shared card's unit, got: \(text)")
        XCTAssertFalse(text.contains("mph"), "Wind must not be shown in a unit unique to this screen")
    }

    // MARK: - State 2: weather present, with AQI

    func test_withAQI_showsAirQualityCard() throws {
        log.weather = weather(aqi: 2)

        let text = try renderedText(makeViewModel())

        XCTAssertTrue(text.contains("air quality"), "got: \(text)")
    }

    // MARK: - State 3: no weather, idle

    func test_withoutWeather_showsEmptyStateAndFetchButton() throws {
        log.weather = nil

        let text = try renderedText(makeViewModel())

        XCTAssertTrue(text.contains("no weather data for this entry"), "got: \(text)")
        XCTAssertTrue(text.contains("get current weather"), "got: \(text)")
    }

    // MARK: - State 4: no weather, refresh in flight

    func test_whileRefreshing_hidesTheFetchPrompt() throws {
        log.weather = nil
        let viewModel = makeViewModel()
        viewModel.isRefreshingWeather = true

        let text = try renderedText(viewModel)

        XCTAssertFalse(
            text.contains("no weather data for this entry"),
            "The empty-state prompt should give way to the loading state, got: \(text)"
        )
    }

    // MARK: - State 5: no weather, refresh failed

    func test_afterRefreshFailure_showsTheError() throws {
        log.weather = nil
        let viewModel = makeViewModel()
        viewModel.weatherRefreshError = "Weather refresh timed out"

        let text = try renderedText(viewModel)

        XCTAssertTrue(text.contains("weather refresh timed out"), "got: \(text)")
    }

    // A refresh error alongside existing weather is not reachable from this
    // screen: the "Get Current Weather" prompt only appears when the entry has
    // no weather, so a failure always leaves weather nil. The shared
    // WeatherDataCard gives the error precedence over the readings, which only
    // matters in a state the UI cannot produce — so there is nothing to assert.
}
