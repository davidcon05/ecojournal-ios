//
//  MapViewModelTests.swift
//  EcoJournalTests
//
//  These test our map logic, not MapKit's rendering. The questions worth
//  asking are which observations earn a pin, how a pin is styled, what the
//  aggregate metrics say when readings are missing, and whether the computed
//  region actually frames every observation — none of which require a map to
//  be drawn.
//

import Testing
import Foundation
import CoreLocation
import MapKit
import SwiftData
@testable import EcoJournal

@MainActor
@Suite("MapViewModel Tests")
struct MapViewModelTests {
    let container: ModelContainer
    let context: ModelContext
    let journal: Journal

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Journal.self, Log.self, AudioMemo.self, configurations: config)
        context = container.mainContext

        journal = Journal(name: "Map Journal")
        context.insert(journal)
        try context.save()
    }

    // MARK: - Fixtures

    @discardableResult
    private func addLog(
        title: String = "Observation",
        latitude: Double? = nil,
        longitude: Double? = nil,
        altitude: Double? = nil,
        weather: Weather? = nil,
        mediaURLs: [URL] = [],
        audioMemoCount: Int = 0
    ) -> Log {
        let log = Log(title: title, notes: "", mediaURLs: mediaURLs)
        context.insert(log)
        log.journal = journal
        log.latitude = latitude
        log.longitude = longitude
        log.altitude = altitude
        log.weather = weather

        for i in 0..<audioMemoCount {
            let memo = AudioMemo(
                title: "Memo \(i)",
                audioURL: URL(fileURLWithPath: "/fake/memo\(i).m4a"),
                duration: 5
            )
            context.insert(memo)
            memo.log = log
        }

        journal.logs.append(log)
        return log
    }

    private func makeWeather(temperature: Double = 20, humidity: Int = 50) -> Weather {
        Weather(
            condition: "Clear",
            temperature: temperature,
            humidity: humidity,
            windSpeed: 5,
            icon: "01d"
        )
    }

    private var sut: MapViewModel { MapViewModel(journal: journal) }

    // MARK: - Which logs earn a pin

    @Test("A journal with no logs has nothing to map")
    func emptyJournal_hasNoMappableLogs() {
        #expect(sut.logsWithGPS.isEmpty)
        #expect(sut.hasMappableLogs == false)
        #expect(sut.regionCoveringAllLogs == nil)
    }

    @Test("Only logs with coordinates are mappable")
    func logsWithoutCoordinates_areExcluded() {
        addLog(title: "Located", latitude: 47.6, longitude: -122.3)
        addLog(title: "No coordinates")

        #expect(sut.logsWithGPS.count == 1)
        #expect(sut.logsWithGPS.first?.title == "Located")
    }

    /// A half-set coordinate is not a location. Treating it as one would put a
    /// pin on the equator or the prime meridian.
    @Test("A log with only a latitude is not mappable")
    func logWithPartialCoordinates_isExcluded() {
        addLog(title: "Half", latitude: 47.6, longitude: nil)

        #expect(sut.logsWithGPS.isEmpty)
        #expect(sut.hasMappableLogs == false)
    }

    @Test("Coordinates are read straight off the mappable logs")
    func coordinates_matchMappableLogs() throws {
        addLog(latitude: 47.6062, longitude: -122.3321)
        addLog(title: "Unmappable")

        let coordinates = sut.coordinates
        #expect(coordinates.count == 1)
        #expect(abs(try #require(coordinates.first).latitude - 47.6062) < 0.0001)
    }

    // MARK: - Pin styling

    @Test("Weather takes precedence in pin styling")
    func pinStyle_prefersWeather() {
        let log = addLog(
            latitude: 1, longitude: 1,
            weather: makeWeather(),
            mediaURLs: [URL(fileURLWithPath: "/fake/a.jpg")],
            audioMemoCount: 1
        )

        #expect(sut.pinStyle(for: log) == .weather)
    }

    @Test("Photos take precedence over audio")
    func pinStyle_prefersPhotoOverAudio() {
        let log = addLog(
            latitude: 1, longitude: 1,
            mediaURLs: [URL(fileURLWithPath: "/fake/a.jpg")],
            audioMemoCount: 1
        )

        #expect(sut.pinStyle(for: log) == .photo)
    }

    @Test("A log with only audio gets the audio pin")
    func pinStyle_audioOnly() {
        let log = addLog(latitude: 1, longitude: 1, audioMemoCount: 1)

        #expect(sut.pinStyle(for: log) == .audio)
    }

    @Test("A log carrying nothing extra gets the plain pin")
    func pinStyle_plain() {
        let log = addLog(latitude: 1, longitude: 1)

        #expect(sut.pinStyle(for: log) == .plain)
    }

    /// Colour and icon used to be chosen by two separate four-way branches.
    /// Every style must supply both, or a pin renders blank.
    @Test("Every pin style has a distinct icon")
    func pinStyle_iconsAreDistinctAndPresent() {
        let icons = LogPinStyle.allCases.map(\.iconName)
        #expect(Set(icons).count == LogPinStyle.allCases.count)
        #expect(icons.contains("") == false)
    }

    // MARK: - Aggregate metrics

    @Test("Metrics show a placeholder when there is nothing to average")
    func metrics_withNoLogs_showPlaceholder() {
        #expect(sut.averageElevation == "—")
        #expect(sut.averageHumidity == "—")
        #expect(sut.averageTemp == "—")
    }

    @Test("Elevation averages across logs that recorded one")
    func averageElevation_averagesAltitudes() {
        addLog(latitude: 1, longitude: 1, altitude: 100)
        addLog(latitude: 2, longitude: 2, altitude: 200)

        #expect(sut.averageElevation == "150m")
    }

    /// A log without an altitude should be skipped, not counted as zero —
    /// otherwise one incomplete observation halves the reported elevation.
    @Test("Logs missing an altitude are skipped rather than counted as zero")
    func averageElevation_ignoresMissingAltitudes() {
        addLog(latitude: 1, longitude: 1, altitude: 100)
        addLog(latitude: 2, longitude: 2, altitude: nil)

        #expect(sut.averageElevation == "100m")
    }

    @Test("Humidity averages only across logs carrying weather")
    func averageHumidity_ignoresLogsWithoutWeather() {
        addLog(latitude: 1, longitude: 1, weather: makeWeather(humidity: 40))
        addLog(latitude: 2, longitude: 2, weather: makeWeather(humidity: 60))
        addLog(latitude: 3, longitude: 3)

        #expect(sut.averageHumidity == "50%")
    }

    @Test("Temperature is averaged in Celsius then shown in Fahrenheit")
    func averageTemp_convertsToFahrenheit() {
        addLog(latitude: 1, longitude: 1, weather: makeWeather(temperature: 0))
        addLog(latitude: 2, longitude: 2, weather: makeWeather(temperature: 100))

        // Mean 50°C -> 122°F
        #expect(sut.averageTemp == "122°F")
    }

    @Test("Metrics ignore logs that are not on the map at all")
    func metrics_ignoreUnmappableLogs() {
        addLog(latitude: 1, longitude: 1, altitude: 100)
        addLog(title: "No coordinates", altitude: 9_000)

        #expect(sut.averageElevation == "100m")
    }

    // MARK: - Region framing

    @Test("The region centres between the extreme observations")
    func region_centersOnBoundingBox() throws {
        addLog(latitude: 10, longitude: 20)
        addLog(latitude: 30, longitude: 40)

        let region = try #require(sut.regionCoveringAllLogs)

        #expect(abs(region.center.latitude - 20) < 0.0001)
        #expect(abs(region.center.longitude - 30) < 0.0001)
    }

    /// The span is padded so pins do not sit against the edge of the screen.
    @Test("The region pads the bounding box so pins are not on the edge")
    func region_padsTheBoundingBox() throws {
        addLog(latitude: 10, longitude: 10)
        addLog(latitude: 20, longitude: 20)

        let region = try #require(sut.regionCoveringAllLogs)

        // 10 degrees of spread, padded by 1.5x
        #expect(abs(region.span.latitudeDelta - 15) < 0.0001)
        #expect(abs(region.span.longitudeDelta - 15) < 0.0001)
    }

    /// Without a floor, one observation would produce a zero span and the map
    /// would zoom in indefinitely.
    @Test("A single observation still gets a usable span")
    func region_singleLog_hasMinimumSpan() throws {
        addLog(latitude: 47.6062, longitude: -122.3321)

        let region = try #require(sut.regionCoveringAllLogs)

        #expect(region.span.latitudeDelta == 0.01)
        #expect(region.span.longitudeDelta == 0.01)
        #expect(abs(region.center.latitude - 47.6062) < 0.0001)
    }

    @Test("The region frames every mappable observation")
    func region_containsAllLogs() throws {
        addLog(latitude: 10, longitude: 10)
        addLog(latitude: 20, longitude: 30)
        addLog(latitude: 15, longitude: -5)

        let region = try #require(sut.regionCoveringAllLogs)

        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLon = region.center.longitude - region.span.longitudeDelta / 2
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2

        for coordinate in sut.coordinates {
            #expect(coordinate.latitude >= minLat && coordinate.latitude <= maxLat)
            #expect(coordinate.longitude >= minLon && coordinate.longitude <= maxLon)
        }
    }

    @Test("Negative coordinates are framed correctly")
    func region_handlesNegativeCoordinates() throws {
        addLog(latitude: -34.6037, longitude: -58.3816)
        addLog(latitude: -33.8688, longitude: -58.0)

        let region = try #require(sut.regionCoveringAllLogs)

        #expect(region.center.latitude < 0)
        #expect(region.center.longitude < 0)
    }
}
