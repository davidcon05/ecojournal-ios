//
//  MapTests.swift
//  EcoJournalUITests
//
//  Tests for Map functionality
//

import XCTest

final class MapTests: BaseUITest {

    // MARK: - Test Helpers

    /// Helper to seed a journal and navigate to Map tab
    private func navigateToMapTab(journalName: String = "Test Journal") {
        launch(seeding: [SeedJournal(name: journalName, isPasswordProtected: false, logs: [])])

        DashboardRobot(app: app)
            .waitForDashboard()
            .selectJournal(named: journalName)

        JournalRobot(app: app)
            .tapMapTab()
    }

    /// Helper to create a log entry with GPS data
    private func createLogWithGPS(title: String) {
        JournalRobot(app: app)
            .tapNewLogTab()

        NewLogRobot(app: app)
            .enterTitle(title)
            .verifyGPSCardExists()
            .tapFinalizeEntry()
    }

    // MARK: - Empty State Tests

    func test_map_showsEmptyState_whenNoLogs() {
        navigateToMapTab()

        MapRobot(app: app)
            .verifyEmptyState()
    }

    // MARK: - Map Display Tests

    // TODO: Re-enable these tests once mock data infrastructure is in place
    // These tests require GPS/location services which don't work reliably in UI tests
    // without proper mocking. See docs/ui-testing-parallelization-requirements.md

    // func test_map_displaysMapView_afterLogCreation() {
    //     navigateToMapTab()
    //
    //     createLogWithGPS(title: "Trail Head")
    //
    //     JournalRobot(app: app)
    //         .tapMapTab()
    //
    //     MapRobot(app: app)
    //         .verifyMapExists()
    // }

    // func test_map_showsPin_forLogWithLocation() {
    //     navigateToMapTab()
    //
    //     createLogWithGPS(title: "Campsite Location")
    //
    //     JournalRobot(app: app)
    //         .tapMapTab()
    //
    //     MapRobot(app: app)
    //         .verifyMapExists()
    //         // Note: Pin verification would require log ID - skipping for now
    // }

    // MARK: - Metrics Panel Tests

    // func test_map_displaysMetricsPanel_whenLogsExist() {
    //     navigateToMapTab()
    //
    //     createLogWithGPS(title: "Hike Start")
    //
    //     JournalRobot(app: app)
    //         .tapMapTab()
    //
    //     MapRobot(app: app)
    //         .verifyMetricsPanelExists()
    // }
}
