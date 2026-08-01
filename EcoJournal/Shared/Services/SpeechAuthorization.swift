//
//  SpeechAuthorization.swift
//  EcoJournal
//
//  Seam around the Speech-framework availability and authorization checks that
//  AudioTranscriptionService makes. Injecting these lets tests drive the
//  "recognizer unavailable" and "not authorized" paths without raising a real
//  system permission dialog.
//
//  Note: the recognition task itself is deliberately *not* behind this seam.
//  Faking it would mean fabricating an SFSpeechRecognitionResult, and a double
//  that returned no task would leave the continuation in `transcribe` waiting
//  forever. That path stays covered by manual/device testing.
//

import Foundation
import Speech

/// Availability + authorization surface used by AudioTranscriptionService.
protocol SpeechAuthorizing: AnyObject {
    var isRecognizerAvailable: Bool { get }
    var authorizationStatus: SFSpeechRecognizerAuthorizationStatus { get }
    func requestAuthorization(_ completion: @escaping (SFSpeechRecognizerAuthorizationStatus) -> Void)
}

/// Talks to the real Speech framework.
nonisolated final class SystemSpeechAuthorizer: SpeechAuthorizing {
    private let recognizer: SFSpeechRecognizer?

    init(recognizer: SFSpeechRecognizer?) {
        self.recognizer = recognizer
    }

    var isRecognizerAvailable: Bool {
        recognizer?.isAvailable ?? false
    }

    var authorizationStatus: SFSpeechRecognizerAuthorizationStatus {
        SFSpeechRecognizer.authorizationStatus()
    }

    func requestAuthorization(_ completion: @escaping (SFSpeechRecognizerAuthorizationStatus) -> Void) {
        SFSpeechRecognizer.requestAuthorization(completion)
    }
}
