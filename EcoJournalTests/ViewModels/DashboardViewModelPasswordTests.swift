//
//  DashboardViewModelPasswordTests.swift
//  EcoJournalTests
//
//  Created by David Contreras on 5/9/26.
//

import Testing
import Foundation
import SwiftData
@testable import EcoJournal

@MainActor
struct DashboardViewModelPasswordTests {

    @Test("Password verification with brute force protection")
    func passwordVerificationFlow() async throws {
        // Given
        let mockKeychain = MockKeychainManager()
        let viewModel = DashboardViewModel(keychainManager: mockKeychain)

        let journal = Journal(name: "Test Journal")
        try mockKeychain.savePassword("correct", for: journal.id.uuidString)
        viewModel.journalToUnlock = journal

        // When: Correct password succeeds
        var result = viewModel.verifyPassword("correct")

        // Then: Success and navigation
        #expect(result == true)
        #expect(viewModel.shouldNavigateToJournal == true)
        #expect(viewModel.failedAttempts[journal.id] == nil)

        // When: Wrong password increments attempts
        viewModel.shouldNavigateToJournal = false
        result = viewModel.verifyPassword("wrong")

        // Then: Failure tracked
        #expect(result == false)
        #expect(viewModel.failedAttempts[journal.id] == 1)
        #expect(viewModel.lockoutMessage == "Incorrect password — 4 attempts remaining")

        // When: 5 total failed attempts
        for _ in 1...4 {
            _ = viewModel.verifyPassword("wrong")
        }

        // Then: Journal locked
        #expect(viewModel.failedAttempts[journal.id] == 5)
        #expect(viewModel.lockedJournals.contains(journal.id) == true)
        #expect(viewModel.lockoutMessage == "Too many failed attempts. Journal locked for 5 minutes.")
    }

    @Test("Biometric unlock with fallback to password")
    func biometricUnlockFlow() async throws {
        // Given: Biometric available and succeeds
        let mockKeychain = MockKeychainManager()
        mockKeychain.biometricAvailable = true
        mockKeychain.biometricAuthResult = true

        let viewModel = DashboardViewModel(keychainManager: mockKeychain)
        let journal = Journal(name: "Test Journal")
        viewModel.journalToUnlock = journal

        // When: Biometric unlock succeeds
        var result = await viewModel.attemptBiometricUnlock(for: journal)

        // Then: Success
        #expect(result == true)
        #expect(viewModel.shouldNavigateToJournal == true)
        #expect(viewModel.showingPasswordPrompt == false)

        // Given: Biometric unavailable
        mockKeychain.biometricAvailable = false
        viewModel.shouldNavigateToJournal = false

        // When: Biometric unavailable
        result = await viewModel.attemptBiometricUnlock(for: journal)

        // Then: Falls back to password prompt
        #expect(result == false)
        #expect(viewModel.showingPasswordPrompt == true)
    }

    @Test("Deleting journal cleans up password and lockout state")
    func deleteJournalCleanup() async throws {
        // Given
        let mockKeychain = MockKeychainManager()
        let viewModel = DashboardViewModel(keychainManager: mockKeychain)
        let container = try ModelContainer(for: Journal.self, Log.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)

        let journal = Journal(name: "Test Journal")
        journal.isPasswordProtected = true
        try mockKeychain.savePassword("password123", for: journal.id.uuidString)
        context.insert(journal)
        try context.save()

        // Set up lockout state
        viewModel.setFailedAttempts(5, for: journal.id)
        viewModel.setLockedJournal(journal.id)

        // When: Delete journal
        viewModel.deleteJournal(journal, modelContext: context)

        // Then: Password and lockout state cleaned up
        #expect(mockKeychain.deletePasswordCallCount == 1)
        #expect(mockKeychain.savedPasswords[journal.id.uuidString] == nil)
        #expect(viewModel.failedAttempts[journal.id] == nil)
        #expect(viewModel.lockedJournals.contains(journal.id) == false)
    }
}
