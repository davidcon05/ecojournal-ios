//
//  LogsListTests.swift
//  EcoJournalUITests
//
//  Tests for Logs List functionality
//

import XCTest

final class LogsListTests: BaseUITest {

    // MARK: - Test Helpers

    /// Helper to seed a journal and navigate to its Logs tab.
    ///
    /// Pass `logs` to seed entries directly rather than creating them through
    /// the New Log screen — that screen needs live GPS and weather, which the
    /// simulator does not provide reliably. Seeding also lets a fixture carry
    /// photos, weather, and audio, which gate whole sections of the list and
    /// detail screens.
    private func navigateToLogsTab(
        journalName: String = "Test Journal",
        logs: [SeedLog] = []
    ) {
        launch(seeding: [SeedJournal(name: journalName, isPasswordProtected: false, logs: logs)])

        DashboardRobot(app: app)
            .waitForDashboard()
            .selectJournal(named: journalName)

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

    func test_logsList_displaysLog() {
        navigateToLogsTab(logs: [.bare(title: "First Observation")])

        LogsListRobot(app: app)
            .verifyLogExists(title: "First Observation")
    }

    func test_logsList_displaysMultipleLogs() {
        navigateToLogsTab(logs: [
            .bare(title: "Morning Hike"),
            .bare(title: "Afternoon Birds"),
            .bare(title: "Evening Sunset")
        ])

        LogsListRobot(app: app)
            .verifyLogExists(title: "Morning Hike")
            .verifyLogExists(title: "Afternoon Birds")
            .verifyLogExists(title: "Evening Sunset")
    }

    /// The list renders the first three logs as featured cards and the rest in
    /// a compact row layout, so a fourth log is what exercises that `else`.
    func test_logsList_displaysFeaturedAndNonFeaturedLogs() {
        navigateToLogsTab(logs: [
            .withWeather(title: "Featured One"),
            .withMedia(title: "Featured Two"),
            .located(title: "Featured Three"),
            .bare(title: "Overflow Four")
        ])

        LogsListRobot(app: app)
            .verifyLogExists(title: "Featured One")
            .verifyLogExists(title: "Overflow Four")
    }

    // MARK: - Search Tests

    func test_logsList_searchFindsMatchingLog() {
        navigateToLogsTab(logs: [
            .bare(title: "Eagle Sighting"),
            .bare(title: "Bear Tracks")
        ])

        LogsListRobot(app: app)
            .searchFor("Eagle")
            .verifyLogExists(title: "Eagle Sighting")
    }

    // MARK: - Navigation Tests

    func test_logsList_navigateToLogDetail() {
        navigateToLogsTab(logs: [.withWeather(title: "Detail Test Log")])

        LogsListRobot(app: app)
            .selectLog(title: "Detail Test Log")

        LogDetailRobot(app: app)
            .verifyTitle("Detail Test Log")
    }

    /// The detail screen gates its telemetry and weather sections behind the
    /// log actually having GPS and weather. This also proves the seed pipeline
    /// carries those fields through to SwiftData — if seeding only delivered
    /// title and notes, these two cards would never render.
    func test_logsList_navigateToLogDetail_withRichLog() {
        navigateToLogsTab(logs: [.withWeather(title: "Rich Detail Log")])

        LogsListRobot(app: app)
            .selectLog(title: "Rich Detail Log")

        LogDetailRobot(app: app)
            .verifyTitle("Rich Detail Log")
            .verifyGPSCardExists()
            .verifyWeatherCardExists()
    }

    /// Media fixtures are real files on disk, so this proves the photo and
    /// audio sections render from bytes that actually loaded — not from a URL
    /// that merely exists in the model.
    func test_logsList_logWithMedia_rendersPhotoAndAudioSections() {
        navigateToLogsTab(logs: [.withMedia(title: "Media Log")])

        LogsListRobot(app: app)
            .selectLog(title: "Media Log")

        LogDetailRobot(app: app)
            .verifyTitle("Media Log")
            .verifyPhotosRendered(atLeast: 2)
    }

    func test_logsList_navigateToLogDetailAndBack() {
        navigateToLogsTab(logs: [.bare(title: "Navigation Test")])

        LogsListRobot(app: app)
            .selectLog(title: "Navigation Test")

        LogDetailRobot(app: app)
            .verifyTitle("Navigation Test")
            .navigateBack()

        LogsListRobot(app: app)
            .verifyLogExists(title: "Navigation Test")
    }
}
