//
//  JournalTests.swift
//  EcoJournalUITests
//
//  Tests for Journal tab navigation and functionality
//

import XCTest

final class JournalTests: BaseUITest {

    // MARK: - Test Helpers

    /// Helper to seed a journal and navigate to it.
    ///
    /// Pass `logs` to seed entries directly rather than creating them through
    /// the New Log screen — that screen needs live GPS and weather, which the
    /// simulator does not provide reliably.
    private func navigateToJournal(
        journalName: String = "Test Journal",
        logs: [SeedLog] = []
    ) {
        launch(seeding: [SeedJournal(name: journalName, isPasswordProtected: false, logs: logs)])

        DashboardRobot(app: app)
            .waitForDashboard()
            .selectJournal(named: journalName)
    }

    /// Helper to create a log entry
    private func createLog(title: String, notes: String = "Test notes") {
        JournalRobot(app: app)
            .tapNewLogTab()

        NewLogRobot(app: app)
            .enterTitle(title)
            .enterNotes(notes)
            .tapFinalizeEntry()
    }

    // MARK: - Tab Navigation Tests

    func test_journal_tabBarExists() {
        navigateToJournal()

        JournalRobot(app: app)
            .verifyJournalTabView()
    }

    func test_journal_navigateToLogsTab() {
        navigateToJournal()

        JournalRobot(app: app)
            .tapLogsTab()

        LogsListRobot(app: app)
            .verifyEmptyState()
    }

    func test_journal_navigateToNewLogTab() {
        navigateToJournal()

        JournalRobot(app: app)
            .tapNewLogTab()

        NewLogRobot(app: app)
            .verifyTitleFieldExists()
    }

    func test_journal_navigateToMapTab() {
        navigateToJournal()

        JournalRobot(app: app)
            .tapMapTab()

        MapRobot(app: app)
            .verifyEmptyState()
    }

    // MARK: - Cross-Tab Data Tests

    // TODO: Re-enable these tests once mock data infrastructure is in place
    // These tests require GPS/location services which don't work reliably in UI tests
    // without proper mocking. See docs/ui-testing-requirements.md for details.

    func test_journal_logAppearsInLogsTab_afterCreation() {
        navigateToJournal()

        createLog(title: "Cross Tab Test")

        JournalRobot(app: app)
            .tapLogsTab()

        LogsListRobot(app: app)
            .verifyLogExists(title: "Cross Tab Test")
    }

    func test_journal_logWithLocationAppearsInMapTab() {
        navigateToJournal(logs: [.located(title: "Map Pin Test")])

        JournalRobot(app: app)
            .tapMapTab()

        MapRobot(app: app)
            .verifyMapExists()
    }

    func test_journal_switchBetweenAllTabs() {
        navigateToJournal(logs: [.located(title: "Multi Tab Test")])

        // Verify Logs tab
        JournalRobot(app: app)
            .tapLogsTab()

        LogsListRobot(app: app)
            .verifyLogExists(title: "Multi Tab Test")

        // Verify Map tab
        JournalRobot(app: app)
            .tapMapTab()

        MapRobot(app: app)
            .verifyMapExists()

        // Verify New Log tab
        JournalRobot(app: app)
            .tapNewLogTab()

        NewLogRobot(app: app)
            .verifyTitleFieldExists()

        // Return to Logs tab
        JournalRobot(app: app)
            .tapLogsTab()

        LogsListRobot(app: app)
            .verifyLogExists(title: "Multi Tab Test")
    }

    // MARK: - Navigation Back Tests

    func test_journal_navigateBackToDashboard() {
        navigateToJournal(journalName: "Nav Test Journal")

        JournalRobot(app: app)
            .navigateBack()

        DashboardRobot(app: app)
            .verifyDashboardTitle()
            .verifyJournalExists(named: "Nav Test Journal")
    }

    func test_journal_navigateBackFromLogsTab() {
        navigateToJournal(journalName: "Logs Nav Test")

        JournalRobot(app: app)
            .tapLogsTab()

        LogsListRobot(app: app)
            .verifyEmptyState()

        JournalRobot(app: app)
            .navigateBack()

        DashboardRobot(app: app)
            .verifyDashboardTitle()
    }
}
