//
//  DashboardViewModelSearchAndSettingsTests.swift
//  EcoJournalTests
//
//  Covers the DashboardViewModel paths the existing suites don't reach:
//  search suggestions, the non-default sort options, the settings
//  (biometric + password) flow, and the prompt/navigation reset helpers.
//
//  All password work goes through MockKeychainManager — no real Keychain.
//

import Testing
import Foundation
import SwiftData
@testable import EcoJournal

@MainActor
@Suite("DashboardViewModel Search & Settings Tests")
struct DashboardViewModelSearchAndSettingsTests {
    let keychain: MockKeychainManager
    let sut: DashboardViewModel

    init() {
        keychain = MockKeychainManager()
        sut = DashboardViewModel(keychainManager: keychain)
    }

    // MARK: - Fixtures

    private func makeJournals(_ names: [String]) -> [Journal] {
        names.map { Journal(name: $0) }
    }

    private func makeProtectedJournal(name: String = "Locked", password: String = "hunter2") throws -> Journal {
        let journal = Journal(name: name)
        journal.isPasswordProtected = true
        try keychain.savePassword(password, for: journal.id.uuidString)
        return journal
    }

    // MARK: - Search Suggestions

    @Test("No suggestions are offered for an empty search")
    func searchSuggestions_whenSearchEmpty_isEmpty() {
        let journals = makeJournals(["Birds", "Trees"])
        sut.searchText = ""

        #expect(sut.searchSuggestions(from: journals).isEmpty)
    }

    @Test("Suggestions match case-insensitively on a substring")
    func searchSuggestions_matchesCaseInsensitiveSubstring() {
        let journals = makeJournals(["Backyard Birds", "Trees", "Shorebirds"])
        sut.searchText = "BIRD"

        let names = sut.searchSuggestions(from: journals).map(\.name)

        #expect(names.count == 2)
        #expect(names.contains("Backyard Birds"))
        #expect(names.contains("Shorebirds"))
    }

    @Test("Prefix matches are ranked above mid-string matches")
    func searchSuggestions_prefersPrefixMatches() {
        let journals = makeJournals(["Shorebirds", "Bird Watching"])
        sut.searchText = "bird"

        let names = sut.searchSuggestions(from: journals).map(\.name)

        #expect(names.first == "Bird Watching")
    }

    @Test("Equally-ranked suggestions fall back to alphabetical order")
    func searchSuggestions_tiesSortAlphabetically() {
        let journals = makeJournals(["Birch", "Birds", "Birdhouse"])
        sut.searchText = "bir"

        let names = sut.searchSuggestions(from: journals).map(\.name)

        #expect(names == ["Birch", "Birdhouse", "Birds"])
    }

    @Test("A search matching nothing yields no suggestions")
    func searchSuggestions_withNoMatch_isEmpty() {
        sut.searchText = "zzzz"

        #expect(sut.searchSuggestions(from: makeJournals(["Birds"])).isEmpty)
    }

    // MARK: - Sorting

    @Test("Oldest-first sorting reverses the default ordering")
    func filteredJournals_oldestFirst_ordersAscending() {
        let older = Journal(name: "Older")
        let newer = Journal(name: "Newer")
        older.lastModified = Date(timeIntervalSince1970: 1_000)
        newer.lastModified = Date(timeIntervalSince1970: 2_000)
        sut.sortOption = .oldestFirst

        let names = sut.filteredJournals(from: [newer, older]).map(\.name)

        #expect(names == ["Older", "Newer"])
    }

    @Test("A-to-Z sorting orders journals alphabetically")
    func filteredJournals_aToZ_ordersAlphabetically() {
        sut.sortOption = .aToZ

        let names = sut.filteredJournals(from: makeJournals(["Zebra", "Apple", "Mango"])).map(\.name)

        #expect(names == ["Apple", "Mango", "Zebra"])
    }

    @Test("Z-to-A sorting reverses alphabetical order")
    func filteredJournals_zToA_ordersReverseAlphabetically() {
        sut.sortOption = .zToA

        let names = sut.filteredJournals(from: makeJournals(["Apple", "Zebra", "Mango"])).map(\.name)

        #expect(names == ["Zebra", "Mango", "Apple"])
    }

    @Test("Search and sort apply together")
    func filteredJournals_appliesSearchThenSort() {
        sut.searchText = "bird"
        sut.sortOption = .aToZ

        let names = sut.filteredJournals(from: makeJournals(["Shorebirds", "Bird Watching", "Trees"])).map(\.name)

        #expect(names == ["Bird Watching", "Shorebirds"])
    }

    // MARK: - Filter State

    @Test("The default sort does not count as an active filter")
    func isFilterActive_withDefaultSort_isFalse() {
        sut.sortOption = .mostRecent
        #expect(sut.isFilterActive == false)
    }

    @Test("Any non-default sort counts as an active filter")
    func isFilterActive_withCustomSort_isTrue() {
        sut.sortOption = .zToA
        #expect(sut.isFilterActive == true)
    }

    @Test("toggleFilterSheet flips the sheet flag")
    func toggleFilterSheet_flipsFlag() {
        sut.toggleFilterSheet()
        #expect(sut.showingFilterSheet == true)

        sut.toggleFilterSheet()
        #expect(sut.showingFilterSheet == false)
    }

    @Test("toggleCreateJournal flips the sheet flag")
    func toggleCreateJournal_flipsFlag() {
        sut.toggleCreateJournal()
        #expect(sut.showingCreateJournal == true)

        sut.toggleCreateJournal()
        #expect(sut.showingCreateJournal == false)
    }

    // MARK: - Opening Settings

    @Test("Settings open immediately for an unprotected journal")
    func openSettings_whenUnprotected_opensDirectly() {
        let journal = Journal(name: "Open")

        sut.openSettings(for: journal)

        #expect(sut.showingSettings == true)
        #expect(sut.selectedJournal === journal)
    }

    @Test("Settings for a protected journal stage it for authentication first")
    func openSettings_whenProtected_requiresAuth() throws {
        let journal = try makeProtectedJournal()

        sut.openSettings(for: journal)

        #expect(sut.showingSettings == false)
        #expect(sut.journalForSettings === journal)
    }

    // MARK: - Biometric Unlock For Settings

    @Test("Without biometrics, settings fall back to the password prompt")
    func biometricSettings_whenUnavailable_promptsForPassword() async throws {
        let journal = try makeProtectedJournal()
        keychain.biometricAvailable = false

        let result = await sut.attemptBiometricUnlockForSettings(for: journal)

        #expect(result == false)
        #expect(sut.showingPasswordPromptForSettings == true)
    }

    @Test("A successful biometric check opens settings")
    func biometricSettings_whenSuccessful_opensSettings() async throws {
        let journal = try makeProtectedJournal()
        keychain.biometricAuthResult = true

        let result = await sut.attemptBiometricUnlockForSettings(for: journal)

        #expect(result == true)
        #expect(sut.showingSettings == true)
        #expect(sut.selectedJournal === journal)
        #expect(sut.journalForSettings == nil)
    }

    @Test("A failed biometric check falls back to the password prompt")
    func biometricSettings_whenFailed_promptsForPassword() async throws {
        let journal = try makeProtectedJournal()
        keychain.biometricAuthResult = false

        let result = await sut.attemptBiometricUnlockForSettings(for: journal)

        #expect(result == false)
        #expect(sut.showingPasswordPromptForSettings == true)
        #expect(sut.showingSettings == false)
    }

    @Test("A locked-out journal refuses biometric unlock for settings")
    func biometricSettings_whenLockedOut_refuses() async throws {
        let journal = try makeProtectedJournal()
        sut.setLockedJournal(journal.id)

        let result = await sut.attemptBiometricUnlockForSettings(for: journal)

        #expect(result == false)
        #expect(sut.lockoutMessage != nil)
        #expect(sut.showingSettings == false)
    }

    // MARK: - Password For Settings

    @Test("Verifying a settings password with no staged journal fails")
    func verifyPasswordForSettings_withoutJournal_returnsFalse() {
        #expect(sut.verifyPasswordForSettings("anything") == false)
    }

    @Test("The correct settings password opens settings and clears attempts")
    func verifyPasswordForSettings_withCorrectPassword_opensSettings() throws {
        let journal = try makeProtectedJournal(password: "correct")
        sut.journalForSettings = journal

        #expect(sut.verifyPasswordForSettings("correct") == true)
        #expect(sut.showingSettings == true)
        #expect(sut.showingPasswordPromptForSettings == false)
        #expect(sut.selectedJournal === journal)
        #expect(sut.lockoutMessage == nil)
    }

    @Test("A wrong settings password reports the remaining attempts")
    func verifyPasswordForSettings_withWrongPassword_reportsRemaining() throws {
        let journal = try makeProtectedJournal(password: "correct")
        sut.journalForSettings = journal

        #expect(sut.verifyPasswordForSettings("wrong") == false)
        #expect(sut.failedAttempts[journal.id] == 1)
        #expect(sut.lockoutMessage == "4 attempts remaining")
        #expect(sut.showingSettings == false)
    }

    @Test("The last remaining attempt is described in the singular")
    func verifyPasswordForSettings_atFourFailures_usesSingular() throws {
        let journal = try makeProtectedJournal(password: "correct")
        sut.journalForSettings = journal
        sut.setFailedAttempts(3, for: journal.id)

        #expect(sut.verifyPasswordForSettings("wrong") == false)
        #expect(sut.lockoutMessage == "1 attempt remaining")
    }

    @Test("Exhausting the attempt budget locks the journal")
    func verifyPasswordForSettings_atMaxFailures_locksJournal() throws {
        let journal = try makeProtectedJournal(password: "correct")
        sut.journalForSettings = journal
        sut.setFailedAttempts(4, for: journal.id)

        #expect(sut.verifyPasswordForSettings("wrong") == false)
        #expect(sut.lockedJournals.contains(journal.id))
        #expect(sut.lockoutMessage == "Too many failed attempts. Journal locked for 5 minutes.")
    }

    @Test("A locked-out journal refuses the settings password outright")
    func verifyPasswordForSettings_whenLockedOut_refuses() throws {
        let journal = try makeProtectedJournal(password: "correct")
        sut.journalForSettings = journal
        sut.setLockedJournal(journal.id)

        #expect(sut.verifyPasswordForSettings("correct") == false)
        #expect(sut.showingSettings == false)
    }

    // MARK: - Journal Access

    @Test("An unprotected journal is entered without a prompt")
    func requestJournalAccess_whenUnprotected_navigatesDirectly() {
        let journal = Journal(name: "Open")

        sut.requestJournalAccess(journal)

        #expect(sut.shouldNavigateToJournal == true)
        #expect(sut.journalToUnlock === journal)
    }

    @Test("Verifying a password with no staged journal fails")
    func verifyPassword_withoutJournal_returnsFalse() {
        #expect(sut.verifyPassword("anything") == false)
    }

    @Test("A locked-out journal refuses the password outright")
    func verifyPassword_whenLockedOut_refuses() throws {
        let journal = try makeProtectedJournal(password: "correct")
        sut.journalToUnlock = journal
        sut.setLockedJournal(journal.id)

        #expect(sut.verifyPassword("correct") == false)
        #expect(sut.shouldNavigateToJournal == false)
    }

    // MARK: - Saving Settings

    @Test("Saving settings with no journal selected does nothing")
    func saveJournalSettings_withoutSelection_doesNothing() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Journal.self, Log.self, configurations: config)

        sut.saveJournalSettings(modelContext: container.mainContext)

        #expect(sut.showingSettings == false)
        #expect(sut.errorMessage == nil)
    }

    @Test("Saving settings closes the sheet and clears the selection")
    func saveJournalSettings_withSelection_closesSheet() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Journal.self, Log.self, configurations: config)
        let journal = Journal(name: "Settings")
        container.mainContext.insert(journal)
        sut.selectedJournal = journal
        sut.showingSettings = true

        sut.saveJournalSettings(modelContext: container.mainContext)

        #expect(sut.showingSettings == false)
        #expect(sut.selectedJournal == nil)
    }

    // MARK: - Cancelling & Reset

    @Test("Cancelling the prompt clears the pending journal")
    func cancelPasswordPrompt_clearsPendingJournal() {
        sut.journalToUnlock = Journal(name: "Pending")
        sut.showingPasswordPrompt = true
        sut.lockoutMessage = "something"

        sut.cancelPasswordPrompt()

        #expect(sut.showingPasswordPrompt == false)
        #expect(sut.lockoutMessage == nil)
        #expect(sut.journalToUnlock == nil)
    }

    @Test("Cancelling keeps the journal when navigation is already underway")
    func cancelPasswordPrompt_whenNavigating_keepsJournal() {
        let journal = Journal(name: "Unlocked")
        sut.journalToUnlock = journal
        sut.shouldNavigateToJournal = true

        sut.cancelPasswordPrompt()

        #expect(sut.journalToUnlock === journal)
    }

    @Test("Cancelling the settings prompt clears its staged journal")
    func cancelPasswordPromptForSettings_clearsState() {
        sut.journalForSettings = Journal(name: "Pending")
        sut.showingPasswordPromptForSettings = true
        sut.lockoutMessage = "something"

        sut.cancelPasswordPromptForSettings()

        #expect(sut.showingPasswordPromptForSettings == false)
        #expect(sut.journalForSettings == nil)
        #expect(sut.lockoutMessage == nil)
    }

    @Test("Resetting navigation clears both the flag and the journal")
    func resetNavigation_clearsState() {
        sut.shouldNavigateToJournal = true
        sut.journalToUnlock = Journal(name: "Visited")

        sut.resetNavigation()

        #expect(sut.shouldNavigateToJournal == false)
        #expect(sut.journalToUnlock == nil)
    }
}
