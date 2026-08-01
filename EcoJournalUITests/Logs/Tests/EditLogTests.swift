//
//  EditLogTests.swift
//  EcoJournalUITests
//
//  Tests for the Edit Log screen, reached from a log's detail view.
//
//  Logs are seeded rather than created through the New Log screen — that
//  screen depends on live GPS and weather the simulator does not provide
//  reliably, and seeding also lets a fixture carry the coordinates and weather
//  that gate the telemetry cards on this screen.
//

import XCTest

final class EditLogTests: BaseUITest {

    // MARK: - Test Helpers

    /// Seeds a journal with one log, opens that log, and taps Edit.
    private func navigateToEditLog(
        log: SeedLog,
        journalName: String = "Test Journal"
    ) {
        launch(seeding: [SeedJournal(name: journalName, isPasswordProtected: false, logs: [log])])

        DashboardRobot(app: app)
            .waitForDashboard()
            .selectJournal(named: journalName)

        JournalRobot(app: app)
            .tapLogsTab()

        LogsListRobot(app: app)
            .selectLog(title: log.title)

        LogDetailRobot(app: app)
            .tapEdit()
    }

    // MARK: - Presentation

    func test_editLog_showsEditScreen_fromLogDetail() {
        navigateToEditLog(log: .bare(title: "Editable Log"))

        EditLogRobot(app: app)
            .verifyOnEditScreen()
            .verifySaveButtonExists()
            .verifyDeleteButtonExists()
    }

    func test_editLog_prefillsTitleFromLog() {
        navigateToEditLog(log: .bare(title: "Prefilled Title"))

        EditLogRobot(app: app)
            .verifyOnEditScreen()
            .verifyTitleField(contains: "Prefilled Title")
    }

    /// The telemetry cards are gated on the log actually carrying coordinates
    /// and weather, so a bare log would never render them.
    func test_editLog_showsTelemetryCards_forLogWithWeather() {
        navigateToEditLog(log: .withWeather(title: "Telemetry Log"))

        EditLogRobot(app: app)
            .verifyOnEditScreen()
            .verifyGPSCardExists()
            .verifyWeatherCardExists()
    }

    // MARK: - Saving

    func test_editLog_savingTitleChange_persistsToDetail() {
        navigateToEditLog(log: .bare(title: "Original Title"))

        EditLogRobot(app: app)
            .verifyOnEditScreen()
            .replaceTitle(with: "Renamed Title")
            .tapSave()

        LogDetailRobot(app: app)
            .verifyTitle("Renamed Title")
    }

    // MARK: - Unsaved Changes

    /// Editing anything hides the normal back button and swaps in one that
    /// warns before discarding.
    func test_editLog_backAfterEditing_warnsAboutUnsavedChanges() {
        navigateToEditLog(log: .bare(title: "Guarded Log"))

        EditLogRobot(app: app)
            .verifyOnEditScreen()
            .replaceTitle(with: "Half Finished Edit")
            .navigateBack()
            .verifyUnsavedChangesAlertShown()
            .keepEditing()

        // Still on the edit screen after choosing to keep editing.
        EditLogRobot(app: app)
            .verifyOnEditScreen()
    }

    func test_editLog_discardingChanges_leavesLogUnchanged() {
        navigateToEditLog(log: .bare(title: "Unchanged Log"))

        EditLogRobot(app: app)
            .verifyOnEditScreen()
            .replaceTitle(with: "Discarded Edit")
            .navigateBack()
            .verifyUnsavedChangesAlertShown()
            .discardChanges()

        LogDetailRobot(app: app)
            .verifyTitle("Unchanged Log")
    }
}
