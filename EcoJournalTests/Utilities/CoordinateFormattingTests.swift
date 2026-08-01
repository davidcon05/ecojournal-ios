//
//  CoordinateFormattingTests.swift
//  EcoJournalTests
//
//  Coordinates are what a researcher takes away from an observation, so the
//  sign matters: it is the difference between a location and its mirror on the
//  opposite side of the equator or prime meridian.
//

import Testing
import Foundation
import CoreLocation
@testable import EcoJournal

@Suite("Coordinate Formatting Tests")
struct CoordinateFormattingTests {

    private func format(_ lat: Double, _ lon: Double) -> String {
        CLLocationCoordinate2D(latitude: lat, longitude: lon).formattedDecimalDegrees
    }

    @Test("A western longitude keeps its minus sign")
    func westernLongitude_keepsMinusSign() {
        #expect(format(47.6062, -122.3321) == "47.6062°, -122.3321°")
    }

    @Test("A southern latitude keeps its minus sign")
    func southernLatitude_keepsMinusSign() {
        #expect(format(-33.8688, 151.2093) == "-33.8688°, 151.2093°")
    }

    @Test("Both hemispheres negative")
    func southWest_keepsBothSigns() {
        #expect(format(-34.6037, -58.3816) == "-34.6037°, -58.3816°")
    }

    @Test("Both hemispheres positive")
    func northEast_hasNoSigns() {
        #expect(format(35.6762, 139.6503) == "35.6762°, 139.6503°")
    }

    @Test("The equator and prime meridian format without a sign")
    func nullIsland_formatsAsZero() {
        #expect(format(0, 0) == "0.0000°, 0.0000°")
    }

    @Test("Coordinates are fixed to four decimal places")
    func precision_isFourDecimalPlaces() {
        // ~11 m resolution, enough to relocate a field observation.
        #expect(format(47.123456789, -122.987654321) == "47.1235°, -122.9877°")
    }

    @Test(
        "A signed value round-trips back to the same number",
        arguments: [
            (47.6062, -122.3321),
            (-33.8688, 151.2093),
            (0.0, -0.1278)
        ]
    )
    func formatted_isParseableBackToCoordinates(lat: Double, lon: Double) throws {
        let parts = format(lat, lon)
            .replacingOccurrences(of: "°", with: "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        let parsedLat = try #require(Double(parts[0]))
        let parsedLon = try #require(Double(parts[1]))

        #expect(abs(parsedLat - lat) < 0.0001)
        #expect(abs(parsedLon - lon) < 0.0001)
    }
}
