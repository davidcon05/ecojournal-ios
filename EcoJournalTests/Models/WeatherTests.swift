//
//  WeatherTests.swift
//  EcoJournalTests
//
//  Created by David Contreras on 5/10/26.
//

import Testing
import Foundation
@testable import EcoJournal

@Suite("Weather Model Tests")
nonisolated struct WeatherTests {

    @Test("Weather initialization with and without air quality")
    func weatherInitialization() {
        // When: Initialize with all parameters
        let weather1 = Weather(
            condition: "Clear",
            temperature: 18.5,
            humidity: 62,
            windSpeed: 3.2,
            icon: "01d",
            aqi: 1,
            pm25: 8.5,
            pm10: 12.3
        )

        // Then: All properties set
        #expect(weather1.condition == "Clear")
        #expect(weather1.temperature == 18.5)
        #expect(weather1.aqi == 1)
        #expect(weather1.pm25 == 8.5)

        // When: Initialize without air quality
        let weather2 = Weather(
            condition: "Rain",
            temperature: 12.0,
            humidity: 88,
            windSpeed: 2.5,
            icon: "10d"
        )

        // Then: Air quality defaults to nil
        #expect(weather2.condition == "Rain")
        #expect(weather2.aqi == nil)
        #expect(weather2.pm25 == nil)
    }

    @Test("AQI description maps values correctly")
    func aqiDescriptionMapping() {
        // Given: Various AQI values
        let validAQI = Weather(condition: "Test", temperature: 20.0, humidity: 50, windSpeed: 1.0, icon: "01d", aqi: 3)
        let invalidAQI = Weather(condition: "Test", temperature: 20.0, humidity: 50, windSpeed: 1.0, icon: "01d", aqi: 99)
        let zeroAQI = Weather(condition: "Test", temperature: 20.0, humidity: 50, windSpeed: 1.0, icon: "01d", aqi: 0)
        let nilAQI = Weather(condition: "Test", temperature: 20.0, humidity: 50, windSpeed: 1.0, icon: "01d")

        // Then: Correct descriptions
        #expect(validAQI.aqiDescription == "Moderate")
        #expect(invalidAQI.aqiDescription == "Unknown")
        #expect(zeroAQI.aqiDescription == "Unknown")
        #expect(nilAQI.aqiDescription == nil)
    }

    // MARK: - Wind Speed Conversion

    /// The API is called with `units=metric`, so `windSpeed` arrives in metres
    /// per second. An earlier version of the detail screen converted it with
    /// the km/h factor (0.621371), under-reporting wind by 3.6x — 5 m/s showed
    /// as 3.1 mph when it is really 11.2 mph.
    @Test("Wind speed converts from metres per second to mph")
    func windSpeed_convertsFromMetresPerSecondToMPH() {
        let weather = Weather(condition: "Clear", temperature: 20, humidity: 50, windSpeed: 5, icon: "01d")

        #expect(abs(weather.windSpeedMPH - 11.1847) < 0.001)
    }

    @Test("A dead calm converts to zero")
    func windSpeed_zeroStaysZero() {
        let weather = Weather(condition: "Clear", temperature: 20, humidity: 50, windSpeed: 0, icon: "01d")

        #expect(weather.windSpeedMPH == 0)
    }

    /// Guards specifically against the km/h factor being used again: at
    /// 10 m/s the wrong conversion gives 6.2 and the right one gives 22.4.
    @Test("The conversion is not the km/h factor")
    func windSpeed_doesNotUseKilometresPerHourFactor() {
        let weather = Weather(condition: "Clear", temperature: 20, humidity: 50, windSpeed: 10, icon: "01d")

        #expect(weather.windSpeedMPH > 20)
        #expect(abs(weather.windSpeedMPH - 6.21371) > 1)
    }
}
