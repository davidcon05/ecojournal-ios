//
//  TelemetryCardComponentTests.swift
//  EcoJournalTests
//
//  Component-level tests for the two telemetry cards, driven with
//  ViewInspector against the real production views.
//
//  These are leaf components: their entire behaviour is input state → rendered
//  output, with no navigation and no environment. Every branch is a
//  combination of (data present?, loading?, error?), which a UI journey can
//  only reach incidentally — a journey shows whichever state the app happened
//  to be in, never the error or mid-flight ones.
//

import XCTest
internal import SwiftUI
import CoreLocation
import ViewInspector
@testable import EcoJournal

@MainActor
final class GPSTelemetryCardTests: XCTestCase {

    private let seattle = CLLocation(latitude: 47.6062, longitude: -122.3321)

    // MARK: - The three display states

    func test_gps_withLocation_showsCoordinates() throws {
        let card = GPSTelemetryCard(location: seattle, isLoading: false, error: nil)

        let text = try card.inspect().findAll(ViewType.Text.self)
            .compactMap { try? $0.string() }
            .joined(separator: " ")

        // Signed decimal degrees: the minus sign is what makes the coordinate
        // directly usable in a mapping tool, so it must survive to the screen.
        XCTAssertTrue(text.contains("47.6062°"), "Latitude should be rendered, got: \(text)")
        XCTAssertTrue(text.contains("-122.3321°"), "Western longitude must keep its minus sign, got: \(text)")
    }

    func test_gps_withError_showsErrorAndNotCoordinates() throws {
        let card = GPSTelemetryCard(
            location: seattle,
            isLoading: false,
            error: "Location permission denied"
        )

        XCTAssertNoThrow(try card.inspect().find(text: "Location permission denied"))
    }

    func test_gps_withNoLocation_rendersPlaceholderState() throws {
        let card = GPSTelemetryCard(location: nil, isLoading: false, error: nil)

        // Must render without crashing on the nil-location branch.
        XCTAssertNoThrow(try card.inspect())
    }

    func test_gps_whileLoading_rendersAcquiringState() throws {
        let card = GPSTelemetryCard(location: nil, isLoading: true, error: nil)

        XCTAssertNoThrow(try card.inspect())
    }

    // MARK: - Refresh affordance

    /// The refresh button appears only when there is an error or a fetch is in
    /// flight — never in the happy path.
    func test_gps_refreshButton_onlyShownForErrorOrLoading() throws {
        let happy = GPSTelemetryCard(location: seattle, isLoading: false, error: nil, onRefresh: {})
        let happyButtons = try happy.inspect().findAll(ViewType.Button.self).count

        let errored = GPSTelemetryCard(location: nil, isLoading: false, error: "No signal", onRefresh: {})
        let erroredButtons = try errored.inspect().findAll(ViewType.Button.self).count

        XCTAssertGreaterThan(erroredButtons, happyButtons, "Refresh should appear in the error state")
    }

    func test_gps_refreshButton_invokesCallback() throws {
        var refreshed = false
        let card = GPSTelemetryCard(
            location: nil,
            isLoading: false,
            error: "No signal",
            onRefresh: { refreshed = true }
        )

        try card.inspect().find(ViewType.Button.self).tap()

        XCTAssertTrue(refreshed, "Tapping refresh should invoke the callback")
    }

    /// With no callback supplied there should be no refresh affordance at all,
    /// even in the error state.
    func test_gps_withoutCallback_showsNoRefresh() throws {
        let card = GPSTelemetryCard(location: nil, isLoading: false, error: "No signal")

        XCTAssertThrowsError(try card.inspect().find(ViewType.Button.self))
    }
}

@MainActor
final class WeatherDataCardTests: XCTestCase {

    private let seattle = CLLocation(latitude: 47.6062, longitude: -122.3321)

    private func weather(aqi: Int? = nil, pm25: Double? = nil) -> Weather {
        Weather(
            condition: "Clear",
            temperature: 72,
            humidity: 50,
            windSpeed: 5,
            icon: "01d",
            aqi: aqi,
            pm25: pm25,
            pm10: nil
        )
    }

    // MARK: - The three display states

    /// The card never renders `weather.condition` as text — it drives the icon
    /// and background gradient only. What the user actually reads are the
    /// metric rows, which fall back to "--" without data.
    func test_weather_withData_showsMetricValues() throws {
        let card = WeatherDataCard(
            weather: weather(),
            location: seattle,
            isLoading: false,
            error: nil
        )

        let text = try card.inspect().findAll(ViewType.Text.self)
            .compactMap { try? $0.string() }
            .joined(separator: " ")

        XCTAssertTrue(text.contains("50%"), "Humidity should be rendered, got: \(text)")
        // 5 m/s is 11.2 mph. Asserting the converted value guards the factor:
        // the km/h factor would render 3.1 here.
        XCTAssertTrue(text.contains("11.2 mph"), "Wind speed should be rendered in mph, got: \(text)")
        XCTAssertFalse(text.contains("--"), "Placeholders should not appear when data is present")
    }

    /// The empty state renders "--" placeholders rather than omitting the rows.
    func test_weather_withNoData_showsPlaceholders() throws {
        let card = WeatherDataCard(weather: nil, location: nil, isLoading: false, error: nil)

        let text = try card.inspect().findAll(ViewType.Text.self)
            .compactMap { try? $0.string() }
            .joined(separator: " ")

        XCTAssertTrue(text.contains("--"), "Missing data should render as placeholders, got: \(text)")
    }

    func test_weather_whileLoading_rendersLoadingState() throws {
        let card = WeatherDataCard(weather: nil, location: seattle, isLoading: true, error: nil)

        XCTAssertNoThrow(try card.inspect())
    }

    func test_weather_withError_showsMessage() throws {
        let card = WeatherDataCard(
            weather: nil,
            location: seattle,
            isLoading: false,
            error: "Weather refresh timed out"
        )

        XCTAssertNoThrow(try card.inspect().find(text: "Weather refresh timed out"))
    }

    func test_weather_withNoData_rendersEmptyState() throws {
        let card = WeatherDataCard(weather: nil, location: nil, isLoading: false, error: nil)

        XCTAssertNoThrow(try card.inspect())
    }

    // MARK: - Air quality is a nested optional branch

    /// AQI renders only when the weather carries both an AQI value and a
    /// description — a nested `if let` a journey would need live API data to
    /// reach.
    func test_weather_withAQI_rendersAirQuality() throws {
        let withAQI = WeatherDataCard(
            weather: weather(aqi: 2, pm25: 12.5),
            location: seattle,
            isLoading: false,
            error: nil
        )
        let withoutAQI = WeatherDataCard(
            weather: weather(),
            location: seattle,
            isLoading: false,
            error: nil
        )

        let withCount = try withAQI.inspect().findAll(ViewType.Text.self).count
        let withoutCount = try withoutAQI.inspect().findAll(ViewType.Text.self).count

        XCTAssertGreaterThan(withCount, withoutCount, "AQI section should add rendered content")
    }

    func test_weather_withPM25_rendersParticulateReading() throws {
        let card = WeatherDataCard(
            weather: weather(aqi: 2, pm25: 12.5),
            location: seattle,
            isLoading: false,
            error: nil
        )

        let text = try card.inspect().findAll(ViewType.Text.self)
            .compactMap { try? $0.string() }
            .joined(separator: " ")

        XCTAssertTrue(text.contains("12"), "PM2.5 reading should be rendered, got: \(text)")
    }

    // MARK: - Refresh affordance

    func test_weather_refreshButton_invokesCallback() throws {
        var refreshed = false
        let card = WeatherDataCard(
            weather: weather(),
            location: seattle,
            isLoading: false,
            error: nil,
            onRefresh: { refreshed = true }
        )

        try card.inspect().find(ViewType.Button.self).tap()

        XCTAssertTrue(refreshed, "Tapping refresh should invoke the callback")
    }
}
