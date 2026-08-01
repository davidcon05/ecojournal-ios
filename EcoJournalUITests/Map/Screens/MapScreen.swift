//
//  MapScreen.swift
//  EcoJournalUITests
//
//  Screen object for Map feature
//

import XCTest

struct MapScreen {
    let app: XCUIApplication

    /// Looks an element up by identifier regardless of its element type.
    ///
    /// SwiftUI decides for itself what type an `.accessibilityIdentifier`
    /// lands on, and it is often not the one you'd expect: `Map` exposes the
    /// identifier on a wrapping `Other` (the real `Map` element is an
    /// unidentified child), and the metrics panel surfaces as `StaticText`.
    /// Querying a specific type here silently finds nothing.
    private func anyElement(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
    }

    // MARK: - Elements

    // Empty State
    var emptyStateIcon: XCUIElement {
        app.images["map.emptyState.icon"].firstMatch
    }

    var emptyStateTitle: XCUIElement {
        app.staticTexts["map.emptyState.title"].firstMatch
    }

    var emptyStateMessage: XCUIElement {
        app.staticTexts["map.emptyState.message"].firstMatch
    }

    // Map
    var mapView: XCUIElement {
        anyElement("map.mapView")
    }

    // Controls
    var centerLocationButton: XCUIElement {
        app.buttons["map.centerLocationButton"].firstMatch
    }

    var metricsPanel: XCUIElement {
        anyElement("map.metricsPanel")
    }

    // Callout
    var calloutCard: XCUIElement {
        anyElement("map.calloutCard")
    }

    var calloutDetailsButton: XCUIElement {
        app.buttons["map.calloutDetailsButton"].firstMatch
    }

    var calloutCloseButton: XCUIElement {
        app.buttons["map.calloutCloseButton"].firstMatch
    }

    // Dynamic Elements
    func pin(logID: String) -> XCUIElement {
        anyElement("map.pin.\(logID)")
    }
}
