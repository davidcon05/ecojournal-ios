//
//  MockWeatherServices.swift
//  EcoJournalTests
//
//  Test doubles for WeatherService and AirQualityService. Neither touches the
//  network — they return canned data, throw, or hang on demand so callers can
//  exercise success, failure, and timeout paths deterministically.
//

import Foundation
@testable import EcoJournal

class MockWeatherService: WeatherService {
    var shouldSucceed = true
    /// When true, sleeps far longer than any test timeout so callers can
    /// exercise their timeout handling.
    var shouldHang = false
    var fetchWeatherCalled = false

    override func fetchWeather(latitude: Double, longitude: Double) async throws -> Weather {
        fetchWeatherCalled = true

        if shouldHang {
            try await Task.sleep(for: .seconds(60))
        }

        if shouldSucceed {
            return Weather(
                condition: "Clear",
                temperature: 72.0,
                humidity: 50,
                windSpeed: 5.0,
                icon: "01d"
            )
        } else {
            throw NSError(domain: "MockWeatherService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }
    }
}

class MockAirQualityService: AirQualityService {
    var shouldSucceed = true
    var shouldHang = false
    var fetchAirQualityCalled = false

    override func fetchAirQuality(latitude: Double, longitude: Double) async throws -> AirQualityData {
        fetchAirQualityCalled = true

        if shouldHang {
            try await Task.sleep(for: .seconds(60))
        }

        if shouldSucceed {
            return AirQualityData(aqi: 2, pm25: 12.5, pm10: 20.0)
        } else {
            throw NSError(domain: "MockAirQualityService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }
    }
}
