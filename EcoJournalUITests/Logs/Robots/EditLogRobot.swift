//
//  EditLogRobot.swift
//  EcoJournalUITests
//
//  Robot pattern for Edit Log screen
//

import XCTest

final class EditLogRobot: BaseRobot {
    private let screen: EditLogScreen

    override init(app: XCUIApplication) {
        self.screen = EditLogScreen(app: app)
        super.init(app: app)
    }

    // MARK: - Verification

    @discardableResult
    func verifyOnEditScreen() -> Self {
        XCTAssertTrue(
            screen.navigationTitle.waitForExistence(timeout: 5),
            "Edit Log screen should be shown"
        )
        return self
    }

    @discardableResult
    func verifyTitleField(contains text: String) -> Self {
        XCTAssertTrue(screen.titleField.waitForExistence(timeout: 5), "Title field should exist")
        let value = screen.titleField.value as? String ?? ""
        XCTAssertTrue(value.contains(text), "Title field should contain '\(text)' but was '\(value)'")
        return self
    }

    @discardableResult
    func verifyGPSCardExists() -> Self {
        XCTAssertTrue(
            screen.gpsTelemetryCard.waitForExistence(timeout: 5),
            "GPS telemetry card should exist"
        )
        return self
    }

    @discardableResult
    func verifyWeatherCardExists() -> Self {
        XCTAssertTrue(
            screen.weatherCard.waitForExistence(timeout: 5),
            "Weather card should exist"
        )
        return self
    }

    @discardableResult
    func verifySaveButtonExists() -> Self {
        XCTAssertTrue(screen.saveButton.waitForExistence(timeout: 5), "Save button should exist")
        return self
    }

    @discardableResult
    func verifyDeleteButtonExists() -> Self {
        XCTAssertTrue(screen.deleteButton.waitForExistence(timeout: 5), "Delete button should exist")
        return self
    }

    // MARK: - Editing

    /// Clears the title field and types a replacement.
    @discardableResult
    func replaceTitle(with text: String) -> Self {
        let field = screen.titleField
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Title field should exist")
        field.tap()

        if let current = field.value as? String, !current.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }

        field.typeText(text)
        return self
    }

    @discardableResult
    func tapSave() -> Self {
        XCTAssertTrue(screen.saveButton.waitForExistence(timeout: 5), "Save button should exist")
        screen.saveButton.tap()
        return self
    }

    @discardableResult
    func tapDelete() -> Self {
        XCTAssertTrue(screen.deleteButton.waitForExistence(timeout: 5), "Delete button should exist")
        screen.deleteButton.tap()
        return self
    }

    @discardableResult
    func navigateBack() -> Self {
        let back = screen.backButton
        XCTAssertTrue(back.waitForExistence(timeout: 5), "Back button should exist")
        back.tap()
        return self
    }

    // MARK: - Unsaved changes

    @discardableResult
    func verifyUnsavedChangesAlertShown() -> Self {
        XCTAssertTrue(
            screen.unsavedChangesAlert.waitForExistence(timeout: 5),
            "Unsaved changes alert should be shown"
        )
        return self
    }

    @discardableResult
    func keepEditing() -> Self {
        screen.keepEditingButton.tap()
        return self
    }

    @discardableResult
    func discardChanges() -> Self {
        screen.discardChangesButton.tap()
        return self
    }
}
