//
//  LogDetailRobot.swift
//  EcoJournalUITests
//
//  Robot pattern for Log Detail screen interactions
//

import XCTest

final class LogDetailRobot: BaseRobot {
    private let screen: LogDetailScreen

    override init(app: XCUIApplication) {
        self.screen = LogDetailScreen(app: app)
        super.init(app: app)
    }

    // MARK: - Actions

    @discardableResult
    func tapEdit() -> Self {
        screen.editButton.tap()
        return self
    }

    @discardableResult
    func tapDelete() -> Self {
        screen.deleteButton.tap()
        return self
    }

    @discardableResult
    func navigateBack() -> Self {
        screen.backButton.tap()
        return self
    }

    // MARK: - Verifications

    @discardableResult
    func verifyTitle(_ title: String) -> Self {
        XCTAssertTrue(screen.titleText.label.contains(title), "Title should contain '\(title)'")
        return self
    }

    @discardableResult
    func verifyNotesExist() -> Self {
        XCTAssertTrue(screen.notesText.exists, "Notes should exist")
        return self
    }

    @discardableResult
    func verifyTimestampExists() -> Self {
        XCTAssertTrue(screen.timestampText.exists, "Timestamp should exist")
        return self
    }

    @discardableResult
    func verifyGPSCardExists() -> Self {
        XCTAssertTrue(screen.gpsTelemetryCard.exists, "GPS telemetry card should exist")
        return self
    }

    @discardableResult
    func verifyWeatherCardExists() -> Self {
        XCTAssertTrue(screen.weatherDataCard.exists, "Weather data card should exist")
        return self
    }

    /// Asserts photos actually rendered, not merely that the section is
    /// present — a log whose media URLs point at nothing still draws the
    /// section, just empty.
    @discardableResult
    func verifyPhotosRendered(atLeast count: Int = 1) -> Self {
        XCTAssertTrue(screen.heroPhoto.waitForExistence(timeout: 5), "Hero section should exist")
        let rendered = screen.heroPhotoThumbnails.count
        XCTAssertGreaterThanOrEqual(
            rendered, count,
            "Expected at least \(count) rendered photo(s), found \(rendered)"
        )
        return self
    }

    @discardableResult
    func verifyHeroPhotoExists() -> Self {
        XCTAssertTrue(screen.heroPhoto.waitForExistence(timeout: 5), "Hero photo should exist")
        return self
    }
}
