//
//  FakeSpeechAuthorizer.swift
//  EcoJournalTests
//
//  Stand-in for the Speech-framework availability/authorization checks, so
//  tests can drive AudioTranscriptionService's guards without raising a real
//  permission dialog.
//

import Foundation
import Speech
@testable import EcoJournal

final class FakeSpeechAuthorizer: SpeechAuthorizing {
    var isRecognizerAvailable: Bool
    var authorizationStatus: SFSpeechRecognizerAuthorizationStatus

    /// Status handed to the completion passed to `requestAuthorization`.
    var statusToGrant: SFSpeechRecognizerAuthorizationStatus

    private(set) var requestAuthorizationCallCount = 0

    init(
        isRecognizerAvailable: Bool = true,
        authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .authorized,
        statusToGrant: SFSpeechRecognizerAuthorizationStatus = .authorized
    ) {
        self.isRecognizerAvailable = isRecognizerAvailable
        self.authorizationStatus = authorizationStatus
        self.statusToGrant = statusToGrant
    }

    func requestAuthorization(_ completion: @escaping (SFSpeechRecognizerAuthorizationStatus) -> Void) {
        requestAuthorizationCallCount += 1
        completion(statusToGrant)
    }
}
