//
//  FakeAudioEngine.swift
//  EcoJournalTests
//
//  In-memory stand-ins for the AVFoundation seams in AudioEngine.swift. These
//  let tests drive AudioRecorderService's record/playback paths without
//  activating an audio session or touching the mic.
//

import Foundation
import AVFoundation
@testable import EcoJournal

// MARK: - Recorder

final class FakeAudioRecorder: AudioRecording {
    let url: URL
    var currentTime: TimeInterval = 0

    private(set) var recordCallCount = 0
    private(set) var stopCallCount = 0
    private(set) var assignedDelegate: AVAudioRecorderDelegate?

    /// What `record()` reports back to the caller.
    var recordSucceeds = true

    init(url: URL) {
        self.url = url
    }

    @discardableResult
    func record() -> Bool {
        recordCallCount += 1
        return recordSucceeds
    }

    func stop() {
        stopCallCount += 1
    }

    func assignDelegate(_ delegate: AVAudioRecorderDelegate?) {
        assignedDelegate = delegate
    }
}

// MARK: - Player

final class FakeAudioPlayer: AudioPlaying {
    var currentTime: TimeInterval = 0
    var duration: TimeInterval

    private(set) var playCallCount = 0
    private(set) var pauseCallCount = 0
    private(set) var stopCallCount = 0
    private(set) var assignedDelegate: AVAudioPlayerDelegate?

    init(duration: TimeInterval = 12) {
        self.duration = duration
    }

    @discardableResult
    func play() -> Bool {
        playCallCount += 1
        return true
    }

    func pause() { pauseCallCount += 1 }
    func stop() { stopCallCount += 1 }

    func assignDelegate(_ delegate: AVAudioPlayerDelegate?) {
        assignedDelegate = delegate
    }
}

// MARK: - Engine

final class FakeAudioEngine: AudioEngine {
    enum Failure: Error { case cannotCreate }

    var recorderToReturn: FakeAudioRecorder?
    var playerToReturn = FakeAudioPlayer()

    var shouldFailToMakeRecorder = false
    var shouldFailToMakePlayer = false

    private(set) var madeRecorderURLs: [URL] = []
    private(set) var madePlayerURLs: [URL] = []
    private(set) var lastRecorderSettings: [String: Any]?

    func makeRecorder(url: URL, settings: [String: Any]) throws -> AudioRecording {
        madeRecorderURLs.append(url)
        lastRecorderSettings = settings

        if shouldFailToMakeRecorder { throw Failure.cannotCreate }

        let recorder = recorderToReturn ?? FakeAudioRecorder(url: url)
        recorderToReturn = recorder
        return recorder
    }

    func makePlayer(contentsOf url: URL) throws -> AudioPlaying {
        madePlayerURLs.append(url)

        if shouldFailToMakePlayer { throw Failure.cannotCreate }

        return playerToReturn
    }
}

// MARK: - Session

final class FakeAudioSession: AudioSessionControlling {
    enum Failure: Error { case denied }

    private(set) var configureCallCount = 0
    private(set) var activationHistory: [Bool] = []

    var shouldFailToConfigure = false
    var shouldFailToActivate = false

    func configureForPlayAndRecord() throws {
        configureCallCount += 1
        if shouldFailToConfigure { throw Failure.denied }
    }

    func setActive(_ active: Bool) throws {
        if shouldFailToActivate && active { throw Failure.denied }
        activationHistory.append(active)
    }
}
