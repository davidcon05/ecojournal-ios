//
//  AudioRecorderService.swift
//  EcoJournal
//
//  Created by David Contreras on 5/13/26.
//

import Foundation
import AVFoundation
internal import Combine

/// Service for recording and playing audio memos
@MainActor
class AudioRecorderService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var playbackProgress: TimeInterval = 0
    @Published var recordingError: String?

    private var audioRecorder: AudioRecording?
    private var audioPlayer: AudioPlaying?
    private var recordingTimer: Timer?
    private var playbackTimer: Timer?

    private let audioEngine: AudioEngine
    private let audioSession: AudioSessionControlling

    // Directory for storing audio files
    private var audioDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioPath = documentsPath.appendingPathComponent("AudioMemos", isDirectory: true)

        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: audioPath.path) {
            try? FileManager.default.createDirectory(at: audioPath, withIntermediateDirectories: true)
        }

        return audioPath
    }

    /// Defaults drive the real AVFoundation stack; tests inject doubles.
    init(
        audioEngine: AudioEngine = SystemAudioEngine(),
        audioSession: AudioSessionControlling = SystemAudioSession()
    ) {
        self.audioEngine = audioEngine
        self.audioSession = audioSession
        super.init()
        // Don't activate audio session until we need it (lazy initialization)
    }

    // MARK: - Audio Session Setup

    private func setupAudioSession() {
        do {
            // Configure but don't activate yet
            try audioSession.configureForPlayAndRecord()
        } catch {
            print("❌ Failed to setup audio session: \(error)")
            recordingError = "Audio session setup failed"
        }
    }

    private func activateAudioSession() {
        do {
            try audioSession.setActive(true)
        } catch {
            print("❌ Failed to activate audio session: \(error)")
            recordingError = "Audio session activation failed"
        }
    }

    private func deactivateAudioSession() {
        do {
            try audioSession.setActive(false)
        } catch {
            print("❌ Failed to deactivate audio session: \(error)")
        }
    }

    // MARK: - Recording

    func startRecording() -> URL? {
        guard !isRecording else { return nil }

        // Setup and activate audio session only when recording starts
        setupAudioSession()
        activateAudioSession()

        let filename = "\(UUID().uuidString).m4a"
        let fileURL = audioDirectory.appendingPathComponent(filename)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try audioEngine.makeRecorder(url: fileURL, settings: settings)
            audioRecorder?.assignDelegate(self)
            audioRecorder?.record()

            isRecording = true
            recordingDuration = 0
            recordingError = nil

            // Start timer to update duration
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    self.recordingDuration = self.audioRecorder?.currentTime ?? 0
                }
            }

            print("✅ Recording started: \(filename)")
            return fileURL
        } catch {
            print("❌ Failed to start recording: \(error)")
            recordingError = error.localizedDescription
            return nil
        }
    }

    func stopRecording() -> URL? {
        guard isRecording, let recorder = audioRecorder else { return nil }

        recorder.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false

        // Deactivate audio session when done recording
        deactivateAudioSession()

        let url = recorder.url
        print("✅ Recording stopped: \(url.lastPathComponent)")
        return url
    }

    func cancelRecording() {
        guard isRecording, let recorder = audioRecorder else { return }

        recorder.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false

        // Deactivate audio session
        deactivateAudioSession()

        // Delete the file
        try? FileManager.default.removeItem(at: recorder.url)
        print("✅ Recording cancelled")
    }

    // MARK: - Playback

    func playAudio(from url: URL) {
        // Stop any existing playback
        stopPlayback()

        do {
            audioPlayer = try audioEngine.makePlayer(contentsOf: url)
            audioPlayer?.assignDelegate(self)
            audioPlayer?.play()

            isPlaying = true
            playbackProgress = 0

            // Start timer to update progress
            playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    self.playbackProgress = self.audioPlayer?.currentTime ?? 0
                }
            }

            print("✅ Playback started: \(url.lastPathComponent)")
        } catch {
            print("❌ Failed to play audio: \(error)")
            recordingError = error.localizedDescription
        }
    }

    func pausePlayback() {
        audioPlayer?.pause()
        playbackTimer?.invalidate()
        playbackTimer = nil
        isPlaying = false
        print("⏸️ Playback paused")
    }

    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil  // Release the audio player to free the file
        playbackTimer?.invalidate()
        playbackTimer = nil
        isPlaying = false
        playbackProgress = 0
        print("⏹️ Playback stopped")
    }

    func deleteAudio(at url: URL) {
        stopPlayback()
        do {
            try FileManager.default.removeItem(at: url)
            print("✅ Audio deleted: \(url.lastPathComponent)")
        } catch {
            print("❌ Failed to delete audio: \(error)")
        }
    }

    // MARK: - Helpers

    func getDuration(for url: URL) -> TimeInterval? {
        do {
            let player = try audioEngine.makePlayer(contentsOf: url)
            return player.duration
        } catch {
            print("❌ Failed to get audio duration: \(error)")
            return nil
        }
    }

    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecorderService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                recordingError = "Recording failed"
                print("❌ Recording did not finish successfully")
            }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            if let error = error {
                recordingError = error.localizedDescription
                print("❌ Recording encode error: \(error)")
            }
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioRecorderService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            stopPlayback()
            print("✅ Playback finished")
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            if let error = error {
                recordingError = error.localizedDescription
                print("❌ Playback decode error: \(error)")
            }
            stopPlayback()
        }
    }
}
