//
//  AudioTranscriptionService.swift
//  EcoJournal
//
//  Created by David Contreras on 5/13/26.
//

import Foundation
import Speech
internal import Combine

/// Service for transcribing audio using Apple's Speech framework
/// Requires NSSpeechRecognitionUsageDescription in Info.plist
@MainActor
class AudioTranscriptionService: ObservableObject {
    @Published var isTranscribing = false
    @Published var transcriptionProgress: Double = 0
    @Published var transcriptionError: String?

    private let speechRecognizer: SFSpeechRecognizer?
    private let authorizer: SpeechAuthorizing
    private var recognitionRequest: SFSpeechURLRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    /// The default authorizer talks to the real Speech framework; tests inject
    /// a double so the availability/authorization guards can be exercised
    /// without raising a permission dialog.
    init(authorizer: SpeechAuthorizing? = nil) {
        // Initialize with user's locale (can be customized to specific language)
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer = recognizer
        self.authorizer = authorizer ?? SystemSpeechAuthorizer(recognizer: recognizer)

        // Check if speech recognition is available
        guard recognizer != nil else {
            print("❌ Speech recognition not available for this locale")
            return
        }

        // Don't request authorization until we actually need it (lazy initialization)
    }

    // MARK: - Authorization

    func requestAuthorization() {
        authorizer.requestAuthorization { authStatus in
            Task { @MainActor in
                switch authStatus {
                case .authorized:
                    print("✅ Speech recognition authorized")
                case .denied:
                    self.transcriptionError = "Speech recognition access denied"
                    print("❌ Speech recognition denied")
                case .restricted:
                    self.transcriptionError = "Speech recognition restricted"
                    print("❌ Speech recognition restricted")
                case .notDetermined:
                    print("⏳ Speech recognition authorization not determined")
                @unknown default:
                    self.transcriptionError = "Unknown authorization status"
                    print("❌ Unknown speech recognition authorization status")
                }
            }
        }
    }

    // MARK: - Transcription

    /// Transcribe audio file to text using on-device speech recognition
    func transcribe(audioURL: URL) async throws -> String {
        guard authorizer.isRecognizerAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }

        // Request authorization if not already determined (lazy request)
        if authorizer.authorizationStatus == .notDetermined {
            requestAuthorization()
            // Wait a bit for authorization (this is async but we need to handle it)
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }

        // Check authorization again
        guard authorizer.authorizationStatus == .authorized else {
            throw TranscriptionError.notAuthorized
        }

        guard let recognizer = speechRecognizer else {
            throw TranscriptionError.recognizerUnavailable
        }

        isTranscribing = true
        transcriptionProgress = 0
        transcriptionError = nil

        recognitionRequest = SFSpeechURLRecognitionRequest(url: audioURL)
        guard let request = recognitionRequest else {
            isTranscribing = false
            throw TranscriptionError.requestFailed
        }

        // Enable on-device recognition (requires language pack download first time)
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        return try await withCheckedThrowingContinuation { continuation in
            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self = self else { return }

                Task { @MainActor in
                    if let error = error {
                        self.isTranscribing = false
                        self.transcriptionError = error.localizedDescription
                        print("❌ Transcription error: \(error)")
                        continuation.resume(throwing: error)
                        return
                    }

                    if let result = result {
                        // Update progress based on whether transcription is final
                        self.transcriptionProgress = result.isFinal ? 1.0 : 0.7

                        if result.isFinal {
                            let transcription = result.bestTranscription.formattedString
                            self.isTranscribing = false
                            print("✅ Transcription complete: \(transcription.prefix(50))...")
                            continuation.resume(returning: transcription)
                        }
                    }
                }
            }
        }
    }

    /// Cancel ongoing transcription
    func cancelTranscription() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isTranscribing = false
        transcriptionProgress = 0
        print("✅ Transcription cancelled")
    }
}

// MARK: - Errors

enum TranscriptionError: LocalizedError {
    case recognizerUnavailable
    case notAuthorized
    case requestFailed

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "Speech recognition is not available for this language"
        case .notAuthorized:
            return "Speech recognition access not authorized. Enable in Settings."
        case .requestFailed:
            return "Failed to create transcription request"
        }
    }
}
