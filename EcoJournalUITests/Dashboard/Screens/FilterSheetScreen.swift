//
//  FilterSheetScreen.swift
//  EcoJournalUITests
//
//  Screen object for the shared FilterSheet.
//
//  FilterSheet is generic over `FilterDisplayable` and reused by both the
//  dashboard and the logs list, so its rows carry no feature-specific
//  identifiers. Each row is a Button whose label is the option's rawValue,
//  which is what we query here.
//

import XCTest

struct FilterSheetScreen {
    let app: XCUIApplication

    var header: XCUIElement {
        app.staticTexts["Sort By"].firstMatch
    }

    /// A sort option row, addressed by its display name (e.g. "Most Recent").
    func option(_ name: String) -> XCUIElement {
        let button = app.buttons[name].firstMatch
        return button.exists ? button : app.staticTexts[name].firstMatch
    }
}
