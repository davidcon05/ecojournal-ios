//
//  UITestFixtureMedia.swift
//  EcoJournal
//
//  Generates real photo and audio files for UI tests.
//
//  Seeded media used to be fabricated URLs pointing at nothing, so a seeded log
//  could claim to have a photo but the gallery had nothing to draw and the
//  player had nothing to open. Anything gated on media actually loading was
//  therefore untestable.
//
//  These are generated at launch rather than bundled as resources: it keeps
//  binary fixtures out of the repository, avoids a target-membership step that
//  is easy to get wrong, and guarantees the files are valid for whatever
//  runtime the tests happen to be on. Everything lands in a single directory
//  that is wiped on each launch, so tests never inherit a previous run's files.
//

import Foundation
import AVFoundation
import UIKit

enum UITestFixtureMedia {
    /// All generated fixtures live here so they can be cleared in one step and
    /// never mix with real user media.
    static var directory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("UITestFixtures", isDirectory: true)
    }

    /// Clears anything left from a previous run and recreates the directory.
    static func reset() {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    // MARK: - Photos

    /// Writes a real JPEG and returns its URL.
    ///
    /// The image is deliberately not a flat colour — a couple of bands make it
    /// obvious in a screenshot which fixture is on screen, and confirms the
    /// bytes survived the round trip rather than a blank view being drawn.
    @discardableResult
    static func makePhoto(
        size: CGSize = CGSize(width: 240, height: 240),
        tint: UIColor = .systemGreen
    ) -> URL? {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            tint.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            UIColor.white.withAlphaComponent(0.35).setFill()
            context.fill(CGRect(x: 0, y: size.height / 3, width: size.width, height: size.height / 3))
        }

        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }

        let url = directory.appendingPathComponent("photo-\(UUID().uuidString).jpg")
        do {
            try data.write(to: url)
            return url
        } catch {
            print("❌ Failed to write fixture photo: \(error)")
            return nil
        }
    }

    // MARK: - Audio

    /// Writes a real, playable `.m4a` of silence and returns its URL.
    ///
    /// Silence is enough: the tests care that a file opens, reports a duration,
    /// and can be handed to a player — not what it sounds like.
    @discardableResult
    static func makeAudio(duration: TimeInterval = 1.0) -> URL? {
        let url = directory.appendingPathComponent("memo-\(UUID().uuidString).m4a")

        let sampleRate = 44_100.0
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.low.rawValue
        ]

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            return nil
        }

        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        buffer.frameLength = frameCount   // zero-filled: silence

        do {
            let file = try AVAudioFile(forWriting: url, settings: settings)
            try file.write(from: buffer)
            return url
        } catch {
            print("❌ Failed to write fixture audio: \(error)")
            return nil
        }
    }
}
