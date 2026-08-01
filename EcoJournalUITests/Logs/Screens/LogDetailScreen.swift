//
//  LogDetailScreen.swift
//  EcoJournalUITests
//
//  Screen object for Log Detail feature
//

import XCTest

struct LogDetailScreen {
    let app: XCUIApplication

    // MARK: - Elements

    /// `HeroPhotoSection` is a container, so SwiftUI spreads this identifier
    /// across the elements it wraps — StaticText, ScrollView — and never onto
    /// an Image. Querying `app.images[...]` matches nothing.
    var heroPhoto: XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "logDetail.heroPhoto")
            .firstMatch
    }

    /// The rendered photo thumbnails. These only exist if the image bytes
    /// actually loaded, which is what makes them worth asserting on.
    var heroPhotoThumbnails: XCUIElementQuery {
        app.descendants(matching: .any)
            .matching(identifier: "logDetail.heroPhoto")
            .element(boundBy: 2)
            .images
    }

    var titleText: XCUIElement {
        app.staticTexts["logDetail.titleText"].firstMatch
    }

    var timestampText: XCUIElement {
        app.staticTexts["logDetail.timestampText"].firstMatch
    }

    var notesText: XCUIElement {
        app.staticTexts["logDetail.notesText"].firstMatch
    }

    var gpsTelemetryCard: XCUIElement {
        app.otherElements["logDetail.gpsTelemetryCard"].firstMatch
    }

    var weatherDataCard: XCUIElement {
        app.otherElements["logDetail.weatherDataCard"].firstMatch
    }

    var editButton: XCUIElement {
        app.buttons["logDetail.editButton"].firstMatch
    }

    var deleteButton: XCUIElement {
        app.buttons["logDetail.deleteButton"].firstMatch
    }

    var backButton: XCUIElement {
        app.navigationBars.buttons.firstMatch
    }
}
