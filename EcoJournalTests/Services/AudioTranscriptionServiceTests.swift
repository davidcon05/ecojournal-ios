//
//  AudioTranscriptionServiceTests.swift
//  EcoJournalTests
//
//  Covers AudioTranscriptionService's observable state, cancellation, and the
//  TranscriptionError messages surfaced to users.
//
//  `transcribe(audioURL:)`'s guards are covered via an injected
//  SpeechAuthorizing double, so no system permission dialog is raised. Its
//  success path is not covered here — that would require fabricating an
//  SFSpeechRecognitionResult, and a double returning no recognition task would
//  leave the continuation waiting forever. See SpeechAuthorization.swift.
//

import Testing
import Foundation
import Speech
@testable import EcoJournal

@MainActor
@Suite("AudioTranscriptionService Tests")
struct AudioTranscriptionServiceTests {
    let authorizer: FakeSpeechAuthorizer
    let sut: AudioTranscriptionService

    init() {
        authorizer = FakeSpeechAuthorizer()
        sut = AudioTranscriptionService(authorizer: authorizer)
    }

    private static let audioURL = URL(fileURLWithPath: "/fake/memo.m4a")

    // MARK: - Initial State

    @Test("A newly created service is idle with no error")
    func initialState_isIdle() {
        #expect(sut.isTranscribing == false)
        #expect(sut.transcriptionProgress == 0)
        #expect(sut.transcriptionError == nil)
    }

    // MARK: - Cancellation

    @Test("cancelTranscription clears in-flight state")
    func cancelTranscription_resetsState() {
        sut.isTranscribing = true
        sut.transcriptionProgress = 0.75

        sut.cancelTranscription()

        #expect(sut.isTranscribing == false)
        #expect(sut.transcriptionProgress == 0)
    }

    @Test("cancelTranscription is safe to call when nothing is running")
    func cancelTranscription_whenIdle_isSafe() {
        sut.cancelTranscription()
        sut.cancelTranscription()

        #expect(sut.isTranscribing == false)
        #expect(sut.transcriptionProgress == 0)
    }

    @Test("cancelTranscription leaves an existing error visible to the user")
    func cancelTranscription_preservesError() {
        sut.transcriptionError = "Speech recognition access denied"

        sut.cancelTranscription()

        #expect(sut.transcriptionError == "Speech recognition access denied")
    }

    // MARK: - Authorization Request

    @Test("requestAuthorization surfaces no error when access is granted")
    func requestAuthorization_whenAuthorized_setsNoError() async {
        authorizer.statusToGrant = .authorized

        sut.requestAuthorization()
        await Task.yield()

        #expect(authorizer.requestAuthorizationCallCount == 1)
        #expect(sut.transcriptionError == nil)
    }

    @Test("requestAuthorization reports denial to the user")
    func requestAuthorization_whenDenied_setsError() async throws {
        authorizer.statusToGrant = .denied

        sut.requestAuthorization()
        try await waitUntil { sut.transcriptionError != nil }

        #expect(sut.transcriptionError == "Speech recognition access denied")
    }

    @Test("requestAuthorization reports a restricted device to the user")
    func requestAuthorization_whenRestricted_setsError() async throws {
        authorizer.statusToGrant = .restricted

        sut.requestAuthorization()
        try await waitUntil { sut.transcriptionError != nil }

        #expect(sut.transcriptionError == "Speech recognition restricted")
    }

    // MARK: - transcribe() Guards

    @Test("transcribe throws recognizerUnavailable when no recognizer is available")
    func transcribe_whenRecognizerUnavailable_throws() async {
        authorizer.isRecognizerAvailable = false

        await #expect(throws: TranscriptionError.recognizerUnavailable) {
            try await sut.transcribe(audioURL: Self.audioURL)
        }
        #expect(sut.isTranscribing == false)
    }

    @Test("transcribe throws notAuthorized when access was denied")
    func transcribe_whenDenied_throwsNotAuthorized() async {
        authorizer.authorizationStatus = .denied

        await #expect(throws: TranscriptionError.notAuthorized) {
            try await sut.transcribe(audioURL: Self.audioURL)
        }
        #expect(sut.isTranscribing == false)
    }

    @Test("transcribe throws notAuthorized when access is restricted")
    func transcribe_whenRestricted_throwsNotAuthorized() async {
        authorizer.authorizationStatus = .restricted

        await #expect(throws: TranscriptionError.notAuthorized) {
            try await sut.transcribe(audioURL: Self.audioURL)
        }
    }

    @Test("transcribe asks for authorization once when status is undetermined")
    func transcribe_whenNotDetermined_requestsAuthorization() async {
        authorizer.authorizationStatus = .notDetermined
        authorizer.statusToGrant = .denied

        // Still unauthorized after the request, so it must give up rather than hang.
        await #expect(throws: TranscriptionError.notAuthorized) {
            try await sut.transcribe(audioURL: Self.audioURL)
        }
        #expect(authorizer.requestAuthorizationCallCount == 1)
    }

    // MARK: - Error Descriptions

    @Test(
        "Each TranscriptionError carries a user-facing description",
        arguments: [
            TranscriptionError.recognizerUnavailable,
            TranscriptionError.notAuthorized,
            TranscriptionError.requestFailed
        ]
    )
    func transcriptionError_hasDescription(error: TranscriptionError) throws {
        let description = try #require(error.errorDescription)
        #expect(description.isEmpty == false)
    }

    @Test("notAuthorized tells the user where to fix it")
    func notAuthorized_mentionsSettings() throws {
        let description = try #require(TranscriptionError.notAuthorized.errorDescription)
        #expect(description.contains("Settings"))
    }

    @Test("TranscriptionError descriptions are distinct from one another")
    func transcriptionError_descriptionsAreDistinct() {
        let descriptions = Set(
            [
                TranscriptionError.recognizerUnavailable,
                TranscriptionError.notAuthorized,
                TranscriptionError.requestFailed
            ].compactMap(\.errorDescription)
        )

        #expect(descriptions.count == 3)
    }

    // MARK: - Helpers

    private func waitUntil(
        timeout: TimeInterval = 2.0,
        condition: @escaping () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { throw WaitTimeoutError() }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    private struct WaitTimeoutError: Error {}
}
