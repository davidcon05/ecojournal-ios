//
//  NewLogTests.swift
//  EcoJournalUITests
//
//  Tests for New Log creation functionality
//

import XCTest

final class NewLogTests: BaseUITest {

    // MARK: - Test Helpers

    /// Helper to seed a journal and navigate to New Log tab
    private func navigateToNewLogTab(journalName: String = "Test Journal") {
        launch(seeding: [SeedJournal(name: journalName, isPasswordProtected: false, logs: [])])

        DashboardRobot(app: app)
            .waitForDashboard()
            .selectJournal(named: journalName)

        JournalRobot(app: app)
            .tapNewLogTab()
    }

    // MARK: - UI Element Tests

    func test_newLog_allFieldsExist() {
        navigateToNewLogTab()

        NewLogRobot(app: app)
            .verifyTitleFieldExists()
            .verifyGPSCardExists()
            .verifyWeatherCardExists()
    }

    func test_newLog_finalizeButtonDisabled_whenTitleEmpty() {
        navigateToNewLogTab()

        NewLogRobot(app: app)
            .verifyFinalizeButtonEnabled(false)
    }

    // MARK: - Log Creation Tests

    // TODO: Re-enable these tests once mock data infrastructure is in place
    // These tests require GPS/location services which don't work reliably in UI tests
    // without proper mocking. See docs/ui-testing-parallelization-requirements.md

    // func test_newLog_createWithTitleOnly() {
    //     navigateToNewLogTab()
    //
    //     NewLogRobot(app: app)
    //         .enterTitle("Quick Observation")
    //         .tapFinalizeEntry()
    //
    //     // Verify navigation to logs list
    //     LogsListRobot(app: app)
    //         .verifyLogExists(title: "Quick Observation")
    // }

    // func test_newLog_createWithTitleAndNotes() {
    //     navigateToNewLogTab()
    //
    //     NewLogRobot(app: app)
    //         .enterTitle("Detailed Entry")
    //         .enterNotes("Found interesting bird species near the trail")
    //         .tapFinalizeEntry()
    //
    //     LogsListRobot(app: app)
    //         .verifyLogExists(title: "Detailed Entry")
    // }

    func test_newLog_finalizeButtonEnabled_whenTitleProvided() {
        navigateToNewLogTab()

        NewLogRobot(app: app)
            .enterTitle("Test Log")
            .verifyFinalizeButtonEnabled(true)
    }

    // MARK: - Data Capture Tests

    // func test_newLog_gpsDataCaptured() {
    //     navigateToNewLogTab()
    //
    //     NewLogRobot(app: app)
    //         .verifyGPSCardExists()
    //         .enterTitle("GPS Test Log")
    //         .tapFinalizeEntry()
    //
    //     LogsListRobot(app: app)
    //         .selectLog(title: "GPS Test Log")
    //
    //     LogDetailRobot(app: app)
    //         .verifyGPSCardExists()
    // }

    // func test_newLog_weatherDataCaptured() {
    //     navigateToNewLogTab()
    //
    //     NewLogRobot(app: app)
    //         .verifyWeatherCardExists()
    //         .enterTitle("Weather Test Log")
    //         .tapFinalizeEntry()
    //
    //     LogsListRobot(app: app)
    //         .selectLog(title: "Weather Test Log")
    //
    //     LogDetailRobot(app: app)
    //         .verifyWeatherCardExists()
    // }
}
