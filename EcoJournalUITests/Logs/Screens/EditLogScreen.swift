//
//  EditLogScreen.swift
//  EcoJournalUITests
//
//  Screen object for Edit Log feature
//

import XCTest

struct EditLogScreen {
    let app: XCUIApplication

    /// Looks an element up by identifier regardless of its element type.
    ///
    /// SwiftUI decides which element type an `.accessibilityIdentifier` lands
    /// on, and it is often not the obvious one — a card built from stacks and
    /// text surfaces as `StaticText` or `Other` rather than anything specific.
    /// Querying one concrete type silently matches nothing.
    private func anyElement(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
    }

    // MARK: - Elements

    var navigationTitle: XCUIElement {
        app.staticTexts["Edit Log"].firstMatch
    }

    var titleField: XCUIElement {
        anyElement("editLog.titleField")
    }

    var notesField: XCUIElement {
        anyElement("editLog.notesField")
    }

    var saveButton: XCUIElement {
        app.buttons["editLog.saveButton"].firstMatch
    }

    var deleteButton: XCUIElement {
        app.buttons["editLog.deleteButton"].firstMatch
    }

    var gpsTelemetryCard: XCUIElement {
        anyElement("editLog.gpsTelemetryCard")
    }

    var weatherCard: XCUIElement {
        anyElement("editLog.weatherCard")
    }

    /// Once there are unsaved changes the view hides the system back button
    /// and supplies its own, labelled "Back", which routes through the
    /// discard-confirmation alert. Fall back to the system button for the
    /// unedited case.
    var backButton: XCUIElement {
        let custom = app.buttons["Back"].firstMatch
        return custom.exists ? custom : app.buttons["BackButton"].firstMatch
    }

    // MARK: - Unsaved-changes alert

    var unsavedChangesAlert: XCUIElement {
        app.alerts["Unsaved Changes"].firstMatch
    }

    var discardChangesButton: XCUIElement {
        unsavedChangesAlert.buttons["Discard Changes"].firstMatch
    }

    var keepEditingButton: XCUIElement {
        unsavedChangesAlert.buttons["Keep Editing"].firstMatch
    }
}
