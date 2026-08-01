//
//  PasswordPromptTests.swift
//  EcoJournalUITests
//
//  Journeys through the password prompt shown when opening a protected
//  journal. The verification and lockout logic is covered by
//  DashboardViewModelSearchAndSettingsTests; these verify the sheet is
//  actually wired to that logic and reflects its results.
//
//  The seeded journal carries a `password`, which the app writes into the
//  Keychain at launch — marking a journal protected is not enough on its own,
//  because the password lives in the Keychain rather than the model.
//

import XCTest

final class PasswordPromptTests: BaseUITest {

    /// Must satisfy the sheet's 8-character minimum, or the Unlock button
    /// stays disabled and taps silently do nothing.
    private static let password = "letmein123"

    private func openProtectedJournal(named name: String = "Private Journal") {
        launch(seeding: [
            SeedJournal(
                name: name,
                isPasswordProtected: true,
                logs: [.bare(title: "Secret Log")],
                password: Self.password
            )
        ])

        DashboardRobot(app: app)
            .waitForDashboard()
            .selectJournal(named: name)
    }

    func test_passwordPrompt_shownForProtectedJournal() {
        openProtectedJournal()

        PasswordPromptRobot(app: app)
            .verifyPromptShown()
    }

    /// DashboardViewModel counts failures and reports how many attempts are
    /// left, which the sheet surfaces as its lockout message.
    func test_passwordPrompt_wrongPassword_reportsRemainingAttempts() {
        openProtectedJournal()

        PasswordPromptRobot(app: app)
            .verifyPromptShown()
            .enterPassword("wrongpassword")
            .tapUnlock()
            .verifyMessageShown(containing: "remaining")
    }

    func test_passwordPrompt_correctPassword_unlocksJournal() {
        openProtectedJournal()

        PasswordPromptRobot(app: app)
            .verifyPromptShown()
            .enterPassword(Self.password)
            .tapUnlock()
            .verifyPromptDismissed()

        JournalRobot(app: app)
            .verifyJournalTabView()
    }
}
