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

    /// Saving a log shows a confirmation alert and leaves the user on the New
    /// Log tab — the app does not navigate anywhere on its own. Tests that go
    /// on to inspect the saved log must dismiss the alert and switch tabs.
    private func finishSavingAndOpenLogsTab() {
        NewLogRobot(app: app)
            .dismissSaveConfirmationAlert()

        JournalRobot(app: app)
            .tapLogsTab()
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

    func test_newLog_createWithTitleOnly() {
        navigateToNewLogTab()

        NewLogRobot(app: app)
            .enterTitle("Quick Observation")
            .tapFinalizeEntry()

        finishSavingAndOpenLogsTab()

        LogsListRobot(app: app)
            .verifyLogExists(title: "Quick Observation")
    }

    func test_newLog_createWithTitleAndNotes() {
        navigateToNewLogTab()

        NewLogRobot(app: app)
            .enterTitle("Detailed Entry")
            .enterNotes("Found interesting bird species near the trail")
            .tapFinalizeEntry()

        finishSavingAndOpenLogsTab()

        LogsListRobot(app: app)
            .verifyLogExists(title: "Detailed Entry")
    }

    func test_newLog_finalizeButtonEnabled_whenTitleProvided() {
        navigateToNewLogTab()

        NewLogRobot(app: app)
            .enterTitle("Test Log")
            .verifyFinalizeButtonEnabled(true)
    }

    // MARK: - Data Capture Tests

    /// Skipped: this asserts that a log *captured through the UI* ends up with
    /// real coordinates, which needs a location fix the simulator does not have
    /// by default. Making it real requires simulating a location (e.g.
    /// `xcrun simctl location <device> set <lat>,<lon>`) *and* handling the
    /// system location-permission prompt, since LocationManager requests
    /// authorization on first use. Seeding cannot substitute here — seeded
    /// coordinates would test the seeder, not the capture flow.
    ///
    /// That the New Log screen *shows* a GPS card is already covered by
    /// `test_newLog_allFieldsExist`, and that the detail screen renders GPS is
    /// covered by `LogsListTests.test_logsList_navigateToLogDetail_withRichLog`.
    func test_newLog_gpsDataCaptured() throws {
        throw XCTSkip("Needs a simulated location and permission handling; simulator has no GPS fix")

        NewLogRobot(app: app)
            .verifyGPSCardExists()
            .enterTitle("GPS Test Log")
            .tapFinalizeEntry()

        finishSavingAndOpenLogsTab()

        LogsListRobot(app: app)
            .selectLog(title: "GPS Test Log")

        LogDetailRobot(app: app)
            .verifyGPSCardExists()
    }

    /// Skipped for the same reason as `test_newLog_gpsDataCaptured`: weather is
    /// fetched from the captured coordinates, so with no location fix there is
    /// nothing to fetch for. Also depends on a live network call to the weather
    /// API, which is not something a UI test should rely on.
    func test_newLog_weatherDataCaptured() throws {
        throw XCTSkip("Depends on a simulated location plus a live weather API call")

        NewLogRobot(app: app)
            .verifyWeatherCardExists()
            .enterTitle("Weather Test Log")
            .tapFinalizeEntry()

        finishSavingAndOpenLogsTab()

        LogsListRobot(app: app)
            .selectLog(title: "Weather Test Log")

        LogDetailRobot(app: app)
            .verifyWeatherCardExists()
    }
}
