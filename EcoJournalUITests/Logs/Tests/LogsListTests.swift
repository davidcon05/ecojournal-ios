//
//  LogsListTests.swift
//  EcoJournalUITests
//
//  Tests for Logs List functionality
//

import XCTest

final class LogsListTests: BaseUITest {

    // MARK: - Test Helpers

    /// Helper to seed a journal and navigate to its Logs tab
    private func navigateToLogsTab(journalName: String = "Test Journal") {
        launch(seeding: [SeedJournal(name: journalName, isPasswordProtected: false, logs: [])])

        DashboardRobot(app: app)
            .waitForDashboard()
            .selectJournal(named: journalName)

        JournalRobot(app: app)
            .tapLogsTab()
    }

    /// Helper to create a log entry
    private func createLog(title: String, notes: String = "Test notes") {
        JournalRobot(app: app)
            .tapNewLogTab()

        NewLogRobot(app: app)
            .enterTitle(title)
            .enterNotes(notes)
            .tapFinalizeEntry()
            .dismissSaveConfirmationAlert()

        JournalRobot(app: app)
            .tapLogsTab()
    }

    // MARK: - Empty State Tests

    func test_logsList_showsEmptyState_whenNoLogs() {
        navigateToLogsTab()

        LogsListRobot(app: app)
            .verifyEmptyState()
    }

    // MARK: - Log Display Tests

    // TODO: Re-enable these tests once mock data infrastructure is in place
    // These tests require GPS/location services which don't work reliably in UI tests
    // without proper mocking. See docs/ui-testing-parallelization-requirements.md

    // func test_logsList_displaysLog_afterCreation() {
    //     navigateToLogsTab()
    //
    //     createLog(title: "First Observation")
    //
    //     LogsListRobot(app: app)
    //         .verifyLogExists(title: "First Observation")
    // }

    // func test_logsList_displaysMultipleLogs() {
    //     navigateToLogsTab()
    //
    //     createLog(title: "Morning Hike")
    //     createLog(title: "Afternoon Birds")
    //     createLog(title: "Evening Sunset")
    //
    //     LogsListRobot(app: app)
    //         .verifyLogExists(title: "Morning Hike")
    //         .verifyLogExists(title: "Afternoon Birds")
    //         .verifyLogExists(title: "Evening Sunset")
    // }

    // MARK: - Search Tests

    // func test_logsList_searchFindsMatchingLog() {
    //     navigateToLogsTab()
    //
    //     createLog(title: "Eagle Sighting")
    //     createLog(title: "Bear Tracks")
    //
    //     LogsListRobot(app: app)
    //         .searchFor("Eagle")
    //         .verifyLogExists(title: "Eagle Sighting")
    // }

    // MARK: - Dropdown Tests

    // TODO: Re-enable once dropdown chevron is re-implemented
    // Validates fix for nested button bug - chevron expands/collapses without navigation
    // func test_featuredCards_expandAndCollapse_togglesContent() {
    //     navigateToLogsTab()
    //     createLog(title: "First Observation", notes: "Testing dropdown behavior")
    //     createLog(title: "Second Observation", notes: "Testing dropdown behavior")
    //
    //     LogsListRobot(app: app)
    //         .verifyLogExists(title: "First Observation", index: 0)
    //         .verifyLogExists(title: "Second Observation", index: 1)
    //         .verifyCardsCollapsed(indices: [0, 1])
    //         .expandCards(indices: [0, 1])
    //         .verifyCardsExpanded(indices: [0, 1])
    //         .collapseCards(indices: [0, 1])
    //         .verifyCardsCollapsed(indices: [0, 1])
    // }

    // MARK: - Navigation Tests

    // func test_logsList_navigateToLogDetail() {
    //     navigateToLogsTab()
    //
    //     createLog(title: "Detail Test Log")
    //
    //     LogsListRobot(app: app)
    //         .selectLog(title: "Detail Test Log")
    //
    //     LogDetailRobot(app: app)
    //         .verifyTitle("Detail Test Log")
    // }

    // func test_logsList_navigateToLogDetailAndBack() {
    //     navigateToLogsTab()
    //
    //     createLog(title: "Navigation Test")
    //
    //     LogsListRobot(app: app)
    //         .selectLog(title: "Navigation Test")
    //
    //     LogDetailRobot(app: app)
    //         .verifyTitle("Navigation Test")
    //         .navigateBack()
    //
    //     LogsListRobot(app: app)
    //         .verifyLogExists(title: "Navigation Test")
    // }
}
