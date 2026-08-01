//
//  FakeLocationManager.swift
//  EcoJournalTests
//
//  Test double for LocationManager. Overrides every method that would reach
//  CoreLocation, so tests never prompt for permission or start real GPS
//  updates. Set `location` / `authorizationStatus` directly to stage state.
//

import Foundation
import CoreLocation
@testable import EcoJournal

@MainActor
final class FakeLocationManager: LocationManager {
    // MARK: - Recorded Calls

    private(set) var requestPermissionCallCount = 0
    private(set) var startUpdatingLocationCallCount = 0
    private(set) var stopUpdatingLocationCallCount = 0

    // MARK: - Overrides

    override func requestPermission() {
        requestPermissionCallCount += 1
        authorizationStatus = .authorizedWhenInUse
    }

    override func startUpdatingLocation() {
        startUpdatingLocationCallCount += 1
    }

    override func stopUpdatingLocation() {
        stopUpdatingLocationCallCount += 1
    }

    // MARK: - Test Helpers

    /// Stage a location without going through CoreLocation delegate callbacks.
    func simulateLocation(latitude: Double, longitude: Double, altitude: Double = 0) {
        location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: altitude,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: Date()
        )
    }

    func reset() {
        location = nil
        locationError = nil
        authorizationStatus = .notDetermined
        requestPermissionCallCount = 0
        startUpdatingLocationCallCount = 0
        stopUpdatingLocationCallCount = 0
    }
}
