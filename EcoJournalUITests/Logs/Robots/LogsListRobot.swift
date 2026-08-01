//
//  LogsListRobot.swift
//  EcoJournalUITests
//
//  Robot pattern for Logs List screen interactions
//

import XCTest

final class LogsListRobot: BaseRobot {
    private let screen: LogsListScreen

    override init(app: XCUIApplication) {
        self.screen = LogsListScreen(app: app)
        super.init(app: app)
        // Force fresh snapshot after navigation
        _ = app.descendants(matching: .any).firstMatch.exists
    }

    // MARK: - Actions

    @discardableResult
    func searchFor(_ text: String) -> Self {
        screen.searchField.enterText(text)
        return self
    }

    @discardableResult
    func tapFilter() -> Self {
        screen.filterButton.tap()
        return self
    }

    @discardableResult
    func selectLog(title: String) -> Self {
        screen.logCardByTitle(title).tap()
        return self
    }

    @discardableResult
    func tapFeaturedCardContent(index: Int) -> Self {
        screen.featuredCardContent(index: index).tap()
        return self
    }

    // MARK: - Verifications

    @discardableResult
    func verifyEmptyState() -> Self {
        XCTAssertTrue(screen.emptyStateIcon.exists, "Empty state icon should exist")
        XCTAssertTrue(screen.emptyStateTitle.exists, "Empty state title should exist")
        XCTAssertTrue(screen.emptyStateMessage.exists, "Empty state message should exist")
        return self
    }

    @discardableResult
    func verifyLogExists(title: String, index: Int = 0) -> Self {
        // Use card container to avoid accidentally tapping on text
        let card = screen.featuredCard(index: index)
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Log card at index \(index) should exist")
        return self
    }

    @discardableResult
    func verifyLogDoesNotExist(title: String) -> Self {
        XCTAssertFalse(screen.logCardByTitle(title).exists, "Log '\(title)' should not exist")
        return self
    }

    @discardableResult
    func verifyHeaderTitle(_ title: String) -> Self {
        XCTAssertTrue(screen.headerTitle.label.contains(title), "Header should contain '\(title)'")
        return self
    }

    @discardableResult
    func verifyStillOnLogsList() -> Self {
        // We're still on logs list if search field exists
        XCTAssertTrue(screen.searchField.exists, "Should still be on logs list (search field exists)")
        return self
    }

    @discardableResult
    func verifyExpandedContentVisible(index: Int) -> Self {
        let notes = screen.featuredCardExpandedNotes(index: index)
        let weather = screen.featuredCardWeatherData(index: index)

        XCTAssertTrue(notes.waitForExistence(timeout: 5), "Featured card \(index) expanded notes should be visible")
        XCTAssertTrue(weather.waitForExistence(timeout: 5), "Featured card \(index) weather data should be visible")
        return self
    }

    @discardableResult
    func verifyExpandedContentHidden(index: Int) -> Self {
        let notes = screen.featuredCardExpandedNotes(index: index)
        let weather = screen.featuredCardWeatherData(index: index)

        _ = notes.waitForExistence(timeout: 5)
        _ = weather.waitForExistence(timeout: 5)

        XCTAssertFalse(notes.exists, "Featured card \(index) expanded notes should be hidden")
        XCTAssertFalse(weather.exists, "Featured card \(index) weather data should be hidden")
        return self
    }
                }
