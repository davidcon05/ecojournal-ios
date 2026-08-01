//
//  AudioRecorderServiceTests.swift
//  EcoJournalTests
//
//  Covers AudioRecorderService end to end, including the record and playback
//  paths. The AVFoundation dependencies are injected via the seams in
//  AudioEngine.swift, so nothing here activates an audio session or touches
//  the mic — see FakeAudioEngine / FakeAudioSession.
//

import Testing
import Foundation
import AVFoundation
@testable import EcoJournal

@MainActor
@Suite("AudioRecorderService Tests")
struct AudioRecorderServiceTests {
    let engine: FakeAudioEngine
    let session: FakeAudioSession
    let sut: AudioRecorderService

    init() {
        engine = FakeAudioEngine()
        session = FakeAudioSession()
        sut = AudioRecorderService(audioEngine: engine, audioSession: session)
    }

    // MARK: - Initial State

    @Test("A newly created service is idle with no error")
    func initialState_isIdle() {
        #expect(sut.isRecording == false)
        #expect(sut.isPlaying == false)
        #expect(sut.recordingDuration == 0)
        #expect(sut.playbackProgress == 0)
        #expect(sut.recordingError == nil)
    }

    // MARK: - formatTime

    @Test(
        "formatTime renders mm:ss, zero-padded",
        arguments: [
            (0.0, "00:00"),
            (5.0, "00:05"),
            (59.0, "00:59"),
            (60.0, "01:00"),
            (61.0, "01:01"),
            (599.0, "09:59"),
            (600.0, "10:00"),
            (3661.0, "61:01")
        ]
    )
    func formatTime_rendersMinutesAndSeconds(seconds: TimeInterval, expected: String) {
        #expect(sut.formatTime(seconds) == expected)
    }

    @Test("formatTime truncates fractional seconds rather than rounding")
    func formatTime_truncatesFractionalSeconds() {
        #expect(sut.formatTime(59.9) == "00:59")
    }

    // MARK: - Recording Guards

    @Test("stopRecording returns nil when nothing is being recorded")
    func stopRecording_whenNotRecording_returnsNil() {
        #expect(sut.stopRecording() == nil)
        #expect(sut.isRecording == false)
    }

    @Test("cancelRecording is a no-op when nothing is being recorded")
    func cancelRecording_whenNotRecording_doesNothing() {
        sut.cancelRecording()

        #expect(sut.isRecording == false)
        #expect(sut.recordingError == nil)
    }

    // MARK: - Playback Guards

    @Test("stopPlayback resets playback state when nothing is playing")
    func stopPlayback_whenNotPlaying_resetsState() {
        sut.stopPlayback()

        #expect(sut.isPlaying == false)
        #expect(sut.playbackProgress == 0)
    }

    @Test("pausePlayback leaves the service not playing when nothing is playing")
    func pausePlayback_whenNotPlaying_staysStopped() {
        sut.pausePlayback()

        #expect(sut.isPlaying == false)
    }

    // MARK: - Recording Lifecycle

    @Test("startRecording configures and activates the audio session")
    func startRecording_activatesSession() throws {
        _ = try #require(sut.startRecording())

        #expect(session.configureCallCount == 1)
        #expect(session.activationHistory == [true])
    }

    @Test("startRecording returns an .m4a URL and begins recording")
    func startRecording_returnsURLAndRecords() throws {
        let url = try #require(sut.startRecording())

        #expect(url.pathExtension == "m4a")
        #expect(sut.isRecording == true)
        #expect(sut.recordingError == nil)
        #expect(engine.recorderToReturn?.recordCallCount == 1)
        #expect(engine.recorderToReturn?.assignedDelegate != nil)
    }

    @Test("startRecording encodes AAC at 44.1kHz mono")
    func startRecording_usesExpectedSettings() throws {
        _ = try #require(sut.startRecording())
        let settings = try #require(engine.lastRecorderSettings)

        #expect(settings[AVSampleRateKey] as? Double == 44100.0)
        #expect(settings[AVNumberOfChannelsKey] as? Int == 1)
    }

    @Test("startRecording is ignored while a recording is already running")
    func startRecording_whenAlreadyRecording_returnsNil() throws {
        _ = try #require(sut.startRecording())

        #expect(sut.startRecording() == nil)
        #expect(engine.madeRecorderURLs.count == 1)
    }

    @Test("startRecording surfaces an error when the recorder cannot be created")
    func startRecording_whenEngineFails_setsError() {
        engine.shouldFailToMakeRecorder = true

        #expect(sut.startRecording() == nil)
        #expect(sut.recordingError != nil)
        #expect(sut.isRecording == false)
    }

    @Test("stopRecording stops the recorder, clears state, and deactivates the session")
    func stopRecording_whileRecording_stopsAndReturnsURL() throws {
        let started = try #require(sut.startRecording())

        let stopped = try #require(sut.stopRecording())

        #expect(stopped == started)
        #expect(sut.isRecording == false)
        #expect(engine.recorderToReturn?.stopCallCount == 1)
        #expect(session.activationHistory == [true, false])
    }

    @Test("cancelRecording stops recording and deletes nothing it did not create")
    func cancelRecording_whileRecording_stopsRecording() throws {
        _ = try #require(sut.startRecording())

        sut.cancelRecording()

        #expect(sut.isRecording == false)
        #expect(engine.recorderToReturn?.stopCallCount == 1)
        #expect(session.activationHistory == [true, false])
    }

    // MARK: - Playback Lifecycle

    @Test("playAudio starts the player and marks the service as playing")
    func playAudio_startsPlayback() {
        sut.playAudio(from: URL(fileURLWithPath: "/fake/memo.m4a"))

        #expect(sut.isPlaying == true)
        #expect(sut.playbackProgress == 0)
        #expect(engine.playerToReturn.playCallCount == 1)
        #expect(engine.playerToReturn.assignedDelegate != nil)
        #expect(sut.recordingError == nil)
    }

    @Test("playAudio stops any in-flight playback before starting the next one")
    func playAudio_whilePlaying_stopsPrevious() {
        let first = engine.playerToReturn
        sut.playAudio(from: URL(fileURLWithPath: "/fake/one.m4a"))

        sut.playAudio(from: URL(fileURLWithPath: "/fake/two.m4a"))

        #expect(first.stopCallCount >= 1)
        #expect(engine.madePlayerURLs.count == 2)
    }

    @Test("pausePlayback pauses the underlying player")
    func pausePlayback_whilePlaying_pausesPlayer() {
        sut.playAudio(from: URL(fileURLWithPath: "/fake/memo.m4a"))

        sut.pausePlayback()

        #expect(sut.isPlaying == false)
        #expect(engine.playerToReturn.pauseCallCount == 1)
    }

    @Test("stopPlayback stops the player and resets progress")
    func stopPlayback_whilePlaying_stopsAndResets() {
        let player = engine.playerToReturn
        sut.playAudio(from: URL(fileURLWithPath: "/fake/memo.m4a"))

        sut.stopPlayback()

        #expect(sut.isPlaying == false)
        #expect(sut.playbackProgress == 0)
        #expect(player.stopCallCount >= 1)
    }

    // MARK: - Error Paths

    @Test("playAudio records an error when the player cannot be created")
    func playAudio_whenEngineFails_setsError() {
        engine.shouldFailToMakePlayer = true

        sut.playAudio(from: URL(fileURLWithPath: "/fake/missing.m4a"))

        #expect(sut.recordingError != nil)
        #expect(sut.isPlaying == false)
    }

    @Test("getDuration reports the player's duration")
    func getDuration_returnsPlayerDuration() {
        engine.playerToReturn = FakeAudioPlayer(duration: 42)

        #expect(sut.getDuration(for: URL(fileURLWithPath: "/fake/memo.m4a")) == 42)
    }

    @Test("getDuration returns nil when the file cannot be opened")
    func getDuration_whenEngineFails_returnsNil() {
        engine.shouldFailToMakePlayer = true

        #expect(sut.getDuration(for: URL(fileURLWithPath: "/fake/missing.m4a")) == nil)
    }

    @Test("deleteAudio on a missing file is handled without crashing")
    func deleteAudio_withMissingFile_doesNotCrash() {
        let missing = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("does-not-exist-\(UUID().uuidString).m4a")

        sut.deleteAudio(at: missing)

        #expect(sut.isPlaying == false)
    }

    @Test("deleteAudio removes an existing file from disk")
    func deleteAudio_withExistingFile_removesIt() throws {
        let file = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("to-delete-\(UUID().uuidString).m4a")
        try Data("placeholder".utf8).write(to: file)
        #expect(FileManager.default.fileExists(atPath: file.path))

        sut.deleteAudio(at: file)

        #expect(FileManager.default.fileExists(atPath: file.path) == false)
    }
}
