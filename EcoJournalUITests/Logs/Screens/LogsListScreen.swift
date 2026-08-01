//
//  LogsListScreen.swift
//  EcoJournalUITests
//
//  Screen object for Logs List feature
//

import XCTest

struct LogsListScreen {
    let app: XCUIApplication

    // MARK: - Elements

    // Empty State
    var emptyStateIcon: XCUIElement {
        app.images["logsList.emptyState.icon"].firstMatch
    }

    var emptyStateTitle: XCUIElement {
        app.staticTexts["logsList.emptyState.title"].firstMatch
    }

    var emptyStateMessage: XCUIElement {
        app.staticTexts["logsList.emptyState.message"].firstMatch
    }

    // Search & Filter
    /// `SearchBarWithDropdown` puts the identifier on a container marked
    /// `.accessibilityElement(children: .contain)`, so the identified element
    /// is an `Other` wrapping the field — querying `app.textFields[id]`
    /// directly matches nothing. Reach the field inside the container.
    var searchField: XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "logsList.searchField")
            .firstMatch
            .textFields
            .firstMatch
    }

    var filterButton: XCUIElement {
        app.buttons["logsList.filterButton"].firstMatch
    }

    // Header
    var headerTitle: XCUIElement {
        app.staticTexts["logsList.headerTitle"].firstMatch
    }

    // Dynamic Elements
    func logCard(id: String) -> XCUIElement {
        app.otherElements["logsList.logCard.\(id)"].firstMatch
    }

    func logCardByTitle(_ title: String) -> XCUIElement {
        app.staticTexts[title].firstMatch
    }

    func featuredCard(index: Int) -> XCUIElement {
        app.otherElements["logsList.featuredCard.\(index)"].firstMatch
    }

    // Featured Card Elements
    func featuredCardChevron(index: Int) -> XCUIElement {
        app.buttons["logsList.featuredCard.\(index).chevron"].firstMatch
    }

    func featuredCardContent(index: Int) -> XCUIElement {
        app.otherElements["logsList.featuredCard.\(index).content"].firstMatch
    }

    func featuredCardExpandedNotes(index: Int) -> XCUIElement {
        app.staticTexts["logsList.featuredCard.\(index).expandedNotes"].firstMatch
    }

    func featuredCardWeatherData(index: Int) -> XCUIElement {
        app.otherElements["logsList.featuredCard.\(index).weatherData"].firstMatch
    }
}
