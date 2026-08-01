//
//  DashboardScreen.swift
//  EcoJournalUITests
//
//  Screen object for Dashboard feature
//

import XCTest

struct DashboardScreen {
    let app: XCUIApplication

    // MARK: - Elements
    // Using actual text labels until accessibility IDs are applied to views

    var newJournalButton: XCUIElement {
        app.buttons["New Journal"].firstMatch
    }

    var searchField: XCUIElement {
        app.textFields["Search Journals..."].firstMatch
    }

    var filterButton: XCUIElement {
        app.buttons.matching(identifier: "dashboard.filterButton").firstMatch
    }

    // Empty State
    var emptyStateIcon: XCUIElement {
        app.images["book.closed.fill"].firstMatch
    }

    var emptyStateTitle: XCUIElement {
        app.staticTexts["No Journals Yet"].firstMatch
    }

    var emptyStateMessage: XCUIElement {
        app.staticTexts["Start by adding a new journal"].firstMatch
    }

    var dashboardTitle: XCUIElement {
        app.staticTexts["Journals"].firstMatch
    }

    // Dynamic Elements
    func journalCardByName(_ name: String) -> XCUIElement {
        app.staticTexts[name].firstMatch
    }

    func sortOption(_ option: String) -> XCUIElement {
        app.buttons[option].firstMatch
    }

    var journalCards: XCUIElementQuery {
        app.otherElements.matching(identifier: "journalCard")
    }

    var lockIcon: XCUIElement {
        app.images.containing(NSPredicate(format: "identifier CONTAINS 'lock'")).firstMatch
    }

    // Dropdown Autocomplete
    func searchSuggestion(_ suggestionText: String) -> XCUIElement {
        app.buttons["searchSuggestion.\(suggestionText)"].firstMatch
    }

    var searchSuggestions: XCUIElementQuery {
        
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'searchSuggestion.'"))
    }
}

struct CreateJournalScreen {
    let app: XCUIApplication

    // MARK: - Elements
    // Using actual text labels until accessibility IDs are applied

    var nameField: XCUIElement {
        app.textFields["Enter name"].firstMatch
    }

    var createButton: XCUIElement {
        app.buttons["Create"].firstMatch
    }

    var nameLabel: XCUIElement {
        app.staticTexts["JOURNAL NAME"].firstMatch
    }

    var sheetTitle: XCUIElement {
        app.staticTexts["New Journal"].firstMatch
    }
}
