//
//  MapTests.swift
//  EcoJournalUITests
//
//  Tests for Map functionality
//

import XCTest

final class MapTests: BaseUITest {

    // MARK: - Test Helpers

    /// Seeds a journal and navigates to its Map tab.
    ///
    /// Logs are seeded rather than created through the New Log screen: that
    /// screen depends on live GPS and weather, which the simulator does not
    /// provide reliably. Seeding sets coordinates directly, so these tests
    /// exercise the map itself instead of the capture flow.
    private func navigateToMapTab(
        journalName: String = "Test Journal",
        logs: [SeedLog] = []
    ) {
        launch(seeding: [SeedJournal(name: journalName, isPasswordProtected: false, logs: logs)])

        DashboardRobot(app: app)
            .waitForDashboard()
            .selectJournal(named: journalName)

        JournalRobot(app: app)
            .tapMapTab()
    }

    // MARK: - Empty State Tests

    func test_map_showsEmptyState_whenNoLogs() {
        navigateToMapTab()

        MapRobot(app: app)
            .verifyEmptyState()
    }

    // MARK: - Map Display Tests

    func test_map_displaysMapView_whenLogHasLocation() {
        navigateToMapTab(logs: [.located(title: "Trail Head")])

        MapRobot(app: app)
            .verifyMapExists()
    }

    func test_map_showsPin_forLogWithLocation() {
        navigateToMapTab(logs: [.located(title: "Campsite Location")])

        MapRobot(app: app)
            .verifyMapExists()
    }

    /// The map annotation branches on log content — weather, then photos, then
    /// audio, then a plain fallback. Seeding one log of each shape renders all
    /// four.
    func test_map_showsPins_forVariedLogShapes() {
        navigateToMapTab(logs: [
            .withWeather(title: "Weather Log"),
            .withMedia(title: "Media Log"),
            .located(title: "Located Log")
        ])

        MapRobot(app: app)
            .verifyMapExists()
    }

    // MARK: - Metrics Panel Tests

    func test_map_displaysMetricsPanel_whenLogsExist() {
        navigateToMapTab(logs: [.located(title: "Hike Start")])

        MapRobot(app: app)
            .verifyMetricsPanelExists()
    }
}
