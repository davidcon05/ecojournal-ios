//
//  MapViewModel.swift
//  EcoJournal
//
//  Logic extracted from MapView: which logs earn a pin, how a pin is styled,
//  the aggregate metrics, and the region that frames a set of observations.
//
//  None of this needs MapKit to render in order to be correct, which is the
//  point — the questions worth asking ("does a log without coordinates get a
//  pin?", "does the region actually contain every observation?") are about our
//  logic, not about whether Apple can draw a map.
//

import Foundation
import SwiftUI
import CoreLocation
import MapKit
internal import Combine

// MARK: - Pin Style

/// How a pin is presented, chosen by what the observation actually captured.
///
/// `MapView` previously answered this twice — once for the colour and once for
/// the icon — with two parallel four-way branches that had to be kept in step
/// by hand. One mapping keeps them honest.
enum LogPinStyle: CaseIterable {
    case weather
    case photo
    case audio
    case plain

    /// Precedence is deliberate: weather, then photos, then audio. A log that
    /// has several still gets one pin, and the richest signal wins.
    static func forLog(_ log: Log) -> LogPinStyle {
        if log.weather != nil {
            return .weather
        } else if !log.mediaURLs.isEmpty {
            return .photo
        } else if !log.audioMemos.isEmpty {
            return .audio
        } else {
            return .plain
        }
    }

    var iconName: String {
        switch self {
        case .weather: return "cloud.sun.fill"
        case .photo: return "camera.fill"
        case .audio: return "mic.fill"
        case .plain: return "mappin.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .weather: return .blue
        case .photo: return .green
        case .audio: return .purple
        case .plain: return .primaryColor
        }
    }
}

// MARK: - View Model

@MainActor
final class MapViewModel: ObservableObject {
    /// Shown wherever a metric has nothing to average.
    static let noValuePlaceholder = "—"

    /// Padding applied around the bounding box so pins do not sit on the edge.
    private static let regionPadding = 1.5

    /// Floor on the span, so a single observation does not zoom to infinity.
    private static let minimumSpan = 0.01

    let journal: Journal

    init(journal: Journal) {
        self.journal = journal
    }

    // MARK: - Which logs appear

    /// Only observations that recorded a position can be placed.
    var logsWithGPS: [Log] {
        journal.logs.filter { $0.latitude != nil && $0.longitude != nil }
    }

    var hasMappableLogs: Bool {
        !logsWithGPS.isEmpty
    }

    var coordinates: [CLLocationCoordinate2D] {
        logsWithGPS.compactMap { log in
            guard let lat = log.latitude, let lon = log.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    // MARK: - Aggregate metrics

    /// Averages ignore observations missing the reading rather than counting
    /// them as zero — one log without weather should not drag the average down.
    var averageElevation: String {
        let altitudes = logsWithGPS.compactMap(\.altitude)
        guard !altitudes.isEmpty else { return Self.noValuePlaceholder }
        let avg = altitudes.reduce(0, +) / Double(altitudes.count)
        return String(format: "%.0fm", avg)
    }

    var averageHumidity: String {
        let humidities = logsWithGPS.compactMap { $0.weather?.humidity }
        guard !humidities.isEmpty else { return Self.noValuePlaceholder }
        let avg = humidities.reduce(0, +) / humidities.count
        return "\(avg)%"
    }

    var averageTemp: String {
        let temps = logsWithGPS.compactMap { $0.weather?.temperature }
        guard !temps.isEmpty else { return Self.noValuePlaceholder }
        let avg = temps.reduce(0, +) / Double(temps.count)
        let fahrenheit = (avg * 9 / 5) + 32
        return String(format: "%.0f°F", fahrenheit)
    }

    // MARK: - Framing

    /// The region that frames every mappable observation, or nil when there is
    /// nothing to frame.
    var regionCoveringAllLogs: MKCoordinateRegion? {
        let coordinates = coordinates
        guard !coordinates.isEmpty else { return nil }

        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)

        guard
            let minLat = latitudes.min(), let maxLat = latitudes.max(),
            let minLon = longitudes.min(), let maxLon = longitudes.max()
        else { return nil }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * Self.regionPadding, Self.minimumSpan),
            longitudeDelta: max((maxLon - minLon) * Self.regionPadding, Self.minimumSpan)
        )

        return MKCoordinateRegion(center: center, span: span)
    }

    // MARK: - Pins

    func pinStyle(for log: Log) -> LogPinStyle {
        LogPinStyle.forLog(log)
    }
}
