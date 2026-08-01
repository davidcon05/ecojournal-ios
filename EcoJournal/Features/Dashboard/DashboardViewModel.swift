//
//  DashboardViewModel.swift
//  EcoJournal
//
//  Created by David Contreras on 5/9/26.
//

import SwiftUI
import SwiftData
internal import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var showingCreateJournal = false
    @Published var showingSettings = false
    @Published var selectedJournal: Journal?
    @Published var showingPasswordPrompt = false
    @Published var journalToUnlock: Journal?
    @Published var showingPasswordPromptForSettings = false
    @Published var journalForSettings: Journal?
    @Published var shouldNavigateToJournal = false
    @Published var errorMessage: String?

    // MARK: - Search & Filter
    @Published var searchText = ""
    @Published var sortOption: SortOption = .mostRecent
    @Published var showingFilterSheet = false

    // MARK: - Brute Force Protection
    @Published private(set) var failedAttempts: [UUID: Int] = [:]
    @Published private(set) var lockedJournals: Set<UUID> = []
    @Published var lockoutMessage: String?

    private let maxPasswordAttempts = 5
    private let lockoutDuration: TimeInterval = 300 // 5 minutes
    private var lockoutTasks: [UUID: Task<Void, Never>] = [:]

    let keychainManager: KeychainManaging // Exposed for View access

    init(keychainManager: KeychainManaging? = nil) {
        self.keychainManager = keychainManager ?? KeychainManager()
    }

    deinit {
        // Cancel all lockout tasks on deinit
        lockoutTasks.values.forEach { $0.cancel() }
    }

    // MARK: - Search & Filter

    func filteredJournals(from journals: [Journal]) -> [Journal] {
        var result = journals

        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter { journal in
                journal.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Apply sort
        switch sortOption {
        case .mostRecent:
            result = result.sorted { $0.lastModified > $1.lastModified }
        case .oldestFirst:
            result = result.sorted { $0.lastModified < $1.lastModified }
        case .aToZ:
            result = result.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .zToA:
            result = result.sorted { $0.name.localizedCompare($1.name) == .orderedDescending }
        }

        return result
    }

    var isFilterActive: Bool {
        sortOption != .mostRecent
    }

    func searchSuggestions(from journals: [Journal]) -> [Journal] {
        guard !searchText.isEmpty else { return [] }

        // Filter journals that match the search text and sort by best match
        return journals
            .filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            .sorted { lhs, rhs in
                let lhsName = lhs.name.lowercased()
                let rhsName = rhs.name.lowercased()
                let search = searchText.lowercased()

                // Prioritize prefix matches
                let lhsStartsWith = lhsName.hasPrefix(search)
                let rhsStartsWith = rhsName.hasPrefix(search)

                if lhsStartsWith != rhsStartsWith {
                    return lhsStartsWith
                }

                // Then sort alphabetically
                return lhsName < rhsName
            }
    }

    func toggleFilterSheet() {
        showingFilterSheet.toggle()
    }

    func createJournal(name: String, modelContext: ModelContext) {
        let journal = Journal(name: name)

        do {
            modelContext.insert(journal)
            try modelContext.save()
            showingCreateJournal = false
        } catch {
            errorMessage = "Failed to create journal: \(error.localizedDescription)"
        }
    }

    func toggleCreateJournal() {
        showingCreateJournal.toggle()
    }

    func openSettings(for journal: Journal) {
        if journal.isPasswordProtected {
            journalForSettings = journal
            // Try biometric authentication first
            Task {
                await attemptBiometricUnlockForSettings(for: journal)
            }
        } else {
            selectedJournal = journal
            showingSettings = true
        }
    }

    func attemptBiometricUnlockForSettings(for journal: Journal) async -> Bool {
        // Check if biometrics are available
        guard keychainManager.isBiometricAvailable() else {
            // No biometrics available, show password prompt
            showingPasswordPromptForSettings = true
            return false
        }

        // Check if journal is locked out
        if lockedJournals.contains(journal.id) {
            lockoutMessage = "Too many failed attempts. Try again in a few minutes."
            showingPasswordPromptForSettings = true
            return false
        }

        // Attempt biometric authentication
        let success = await keychainManager.authenticateWithBiometrics(for: journal.name)

        if success {
            // Biometric authentication succeeded
            failedAttempts.removeValue(forKey: journal.id)
            lockoutMessage = nil
            selectedJournal = journal
            showingSettings = true
            journalForSettings = nil
            return true
        } else {
            // Biometric authentication failed or cancelled - show password prompt as fallback
            showingPasswordPromptForSettings = true
            return false
        }
    }

    func verifyPasswordForSettings(_ password: String) -> Bool {
        guard let journal = journalForSettings else { return false }

        // Check if journal is locked out
        if lockedJournals.contains(journal.id) {
            lockoutMessage = "Too many failed attempts. Try again in a few minutes."
            return false
        }

        let isValid = keychainManager.verifyPassword(password, for: journal.id.uuidString)

        if isValid {
            // Reset failed attempts on success
            failedAttempts.removeValue(forKey: journal.id)
            lockoutMessage = nil
            showingPasswordPromptForSettings = false
            selectedJournal = journal
            showingSettings = true
            journalForSettings = nil
            return true
        } else {
            // Increment failed attempts
            let attempts = (failedAttempts[journal.id] ?? 0) + 1
            failedAttempts[journal.id] = attempts

            // Check if max attempts reached
            if attempts >= maxPasswordAttempts {
                lockJournal(journal.id)
                lockoutMessage = "Too many failed attempts. Journal locked for 5 minutes."
            } else {
                let remainingAttempts = maxPasswordAttempts - attempts
                // Say why, not just how many left — on its own, "4 attempts
                // remaining" never tells the user the password was wrong.
                lockoutMessage = "Incorrect password — \(remainingAttempts) attempt\(remainingAttempts == 1 ? "" : "s") remaining"
            }

            return false
        }
    }

    func saveJournalSettings(modelContext: ModelContext) {
        guard selectedJournal != nil else { return }

        do {
            try modelContext.save()
            showingSettings = false
            selectedJournal = nil
        } catch {
            errorMessage = "Failed to save journal settings: \(error.localizedDescription)"
        }
    }

    func deleteJournal(_ journal: Journal, modelContext: ModelContext) {
        do {
            // Clean up password from Keychain if journal is protected
            if journal.isPasswordProtected {
                try? keychainManager.deletePassword(for: journal.id.uuidString)
            }

            // Clean up any failed attempts tracking
            failedAttempts.removeValue(forKey: journal.id)
            lockedJournals.remove(journal.id)
            lockoutTasks[journal.id]?.cancel()
            lockoutTasks.removeValue(forKey: journal.id)

            modelContext.delete(journal)
            try modelContext.save()
            showingSettings = false
            selectedJournal = nil
        } catch {
            errorMessage = "Failed to delete journal: \(error.localizedDescription)"
        }
    }

    // MARK: - Password Protection

    func requestJournalAccess(_ journal: Journal) {
        journalToUnlock = journal

        if journal.isPasswordProtected {
            // Try biometric authentication first
            Task {
                await attemptBiometricUnlock(for: journal)
            }
        } else {
            // Journal is not locked, proceed directly
            shouldNavigateToJournal = true
        }
    }

    func attemptBiometricUnlock(for journal: Journal) async -> Bool {
        // Check if biometrics are available
        guard keychainManager.isBiometricAvailable() else {
            // No biometrics available, show password prompt
            showingPasswordPrompt = true
            return false
        }

        // Check if journal is locked out
        if lockedJournals.contains(journal.id) {
            lockoutMessage = "Too many failed attempts. Try again in a few minutes."
            showingPasswordPrompt = true
            return false
        }

        // Attempt biometric authentication
        let success = await keychainManager.authenticateWithBiometrics(for: journal.name)

        if success {
            // Biometric authentication succeeded
            failedAttempts.removeValue(forKey: journal.id)
            lockoutMessage = nil
            shouldNavigateToJournal = true
            return true
        } else {
            // Biometric authentication failed or cancelled - show password prompt as fallback
            showingPasswordPrompt = true
            return false
        }
    }

    func verifyPassword(_ password: String) -> Bool {
        guard let journal = journalToUnlock else { return false }

        // Check if journal is locked out
        if lockedJournals.contains(journal.id) {
            lockoutMessage = "Too many failed attempts. Try again in a few minutes."
            return false
        }

        let isValid = keychainManager.verifyPassword(password, for: journal.id.uuidString)

        if isValid {
            // Reset failed attempts on success
            failedAttempts.removeValue(forKey: journal.id)
            lockoutMessage = nil
            showingPasswordPrompt = false
            shouldNavigateToJournal = true
            return true
        } else {
            // Increment failed attempts
            let attempts = (failedAttempts[journal.id] ?? 0) + 1
            failedAttempts[journal.id] = attempts

            // Check if max attempts reached
            if attempts >= maxPasswordAttempts {
                lockJournal(journal.id)
                lockoutMessage = "Too many failed attempts. Journal locked for 5 minutes."
            } else {
                let remainingAttempts = maxPasswordAttempts - attempts
                // Say why, not just how many left — on its own, "4 attempts
                // remaining" never tells the user the password was wrong.
                lockoutMessage = "Incorrect password — \(remainingAttempts) attempt\(remainingAttempts == 1 ? "" : "s") remaining"
            }

            return false
        }
    }

    private func lockJournal(_ journalID: UUID) {
        lockedJournals.insert(journalID)

        // Cancel existing lockout task if any
        lockoutTasks[journalID]?.cancel()

        // Create lockout timer
        let task = Task {
            try? await Task.sleep(nanoseconds: UInt64(lockoutDuration * 1_000_000_000))

            // Check if task wasn't cancelled
            guard !Task.isCancelled else { return }

            // Unlock journal
            lockedJournals.remove(journalID)
            failedAttempts.removeValue(forKey: journalID)
            lockoutMessage = nil
            lockoutTasks.removeValue(forKey: journalID)
        }

        lockoutTasks[journalID] = task
    }

    func cancelPasswordPrompt() {
        showingPasswordPrompt = false
        lockoutMessage = nil
        // Don't clear journalToUnlock here - it's needed for navigation
        // It will be cleared in resetNavigation() when user navigates back
        if !shouldNavigateToJournal {
            // Only clear if we're not about to navigate (user actually cancelled)
            journalToUnlock = nil
        }
    }

    func cancelPasswordPromptForSettings() {
        showingPasswordPromptForSettings = false
        journalForSettings = nil
        lockoutMessage = nil
    }

    func resetNavigation() {
        shouldNavigateToJournal = false
        journalToUnlock = nil
    }

    // MARK: - Test Helpers

    #if DEBUG
    internal func setFailedAttempts(_ attempts: Int, for journalID: UUID) {
        failedAttempts[journalID] = attempts
    }

    internal func setLockedJournal(_ journalID: UUID) {
        lockedJournals.insert(journalID)
    }
    #endif
}
