//
//  AudioEngine.swift
//  EcoJournal
//
//  Seams around the AVFoundation types AudioRecorderService drives, so tests
//  can substitute doubles instead of activating a real audio session and mic.
//  Same idea as WeatherService taking a `URLSessionProtocol`: inject the
//  boundary, keep the logic.
//

import Foundation
import AVFoundation

// MARK: - Protocols

/// The AVAudioSession calls AudioRecorderService makes.
protocol AudioSessionControlling: AnyObject {
    func configureForPlayAndRecord() throws
    func setActive(_ active: Bool) throws
}

/// The slice of AVAudioRecorder AudioRecorderService uses.
protocol AudioRecording: AnyObject {
    var url: URL { get }
    var currentTime: TimeInterval { get }

    @discardableResult
    func record() -> Bool
    func stop()
    func assignDelegate(_ delegate: AVAudioRecorderDelegate?)
}

/// The slice of AVAudioPlayer AudioRecorderService uses.
protocol AudioPlaying: AnyObject {
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }

    @discardableResult
    func play() -> Bool
    func pause()
    func stop()
    func assignDelegate(_ delegate: AVAudioPlayerDelegate?)
}

/// Creates the recorder/player objects. Injecting this is what lets tests
/// exercise start/stop/playback without hardware.
protocol AudioEngine {
    func makeRecorder(url: URL, settings: [String: Any]) throws -> AudioRecording
    func makePlayer(contentsOf url: URL) throws -> AudioPlaying
}

// MARK: - AVFoundation Conformances

extension AVAudioRecorder: AudioRecording {
    func assignDelegate(_ delegate: AVAudioRecorderDelegate?) {
        self.delegate = delegate
    }
}

extension AVAudioPlayer: AudioPlaying {
    func assignDelegate(_ delegate: AVAudioPlayerDelegate?) {
        self.delegate = delegate
    }
}

// MARK: - Live Implementations

/// Drives the real AVAudioSession.
nonisolated final class SystemAudioSession: AudioSessionControlling {
    func configureForPlayAndRecord() throws {
        try AVAudioSession.sharedInstance().setCategory(
            .playAndRecord,
            mode: .default,
            options: [.defaultToSpeaker]
        )
    }

    func setActive(_ active: Bool) throws {
        let session = AVAudioSession.sharedInstance()
        if active {
            try session.setActive(true)
        } else {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}

/// Builds real AVAudioRecorder / AVAudioPlayer instances.
nonisolated final class SystemAudioEngine: AudioEngine {
    func makeRecorder(url: URL, settings: [String: Any]) throws -> AudioRecording {
        try AVAudioRecorder(url: url, settings: settings)
    }

    func makePlayer(contentsOf url: URL) throws -> AudioPlaying {
        try AVAudioPlayer(contentsOf: url)
    }
}
