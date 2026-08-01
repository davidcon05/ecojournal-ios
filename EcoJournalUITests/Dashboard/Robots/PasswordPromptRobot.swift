//
//  PasswordPromptRobot.swift
//  EcoJournalUITests
//
//  Robot pattern for the shared PasswordPromptSheet.
//

import XCTest

final class PasswordPromptRobot: BaseRobot {
    private let screen: PasswordPromptScreen

    override init(app: XCUIApplication) {
        self.screen = PasswordPromptScreen(app: app)
        super.init(app: app)
    }

    @discardableResult
    func verifyPromptShown() -> Self {
        XCTAssertTrue(screen.title.waitForExistence(timeout: 5), "Password prompt should be shown")
        return self
    }

    @discardableResult
    func verifyPromptDismissed() -> Self {
        XCTAssertTrue(
            screen.title.waitForNonExistence(timeout: 5),
            "Password prompt should close after a successful unlock"
        )
        return self
    }

    @discardableResult
    func enterPassword(_ password: String) -> Self {
        let field = screen.passwordField
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Password field should exist")
        field.tap()
        field.typeText(password)
        return self
    }

    @discardableResult
    func tapUnlock() -> Self {
        let button = screen.unlockButton
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Unlock button should exist")
        // The sheet disables Unlock until the password meets its minimum
        // length; tapping a disabled button silently does nothing, which is
        // painful to diagnose from a downstream assertion.
        XCTAssertTrue(button.isEnabled, "Unlock button should be enabled — is the password long enough?")
        button.tap()
        return self
    }

    @discardableResult
    func verifyIncorrectPasswordShown() -> Self {
        XCTAssertTrue(
            screen.incorrectPasswordMessage.waitForExistence(timeout: 5),
            "An incorrect-password message should be shown"
        )
        return self
    }

    @discardableResult
    func verifyMessageShown(containing text: String) -> Self {
        XCTAssertTrue(
            screen.message(containing: text).waitForExistence(timeout: 5),
            "A message containing '\(text)' should be shown"
        )
        return self
    }
}
