//
//  PhotoStorageService.swift
//  EcoJournal
//
//  Created by David Contreras on 5/13/26.
//

import Foundation
import UIKit

/// Service for saving and managing photos for log entries
///
/// `nonisolated` because this is stateless file I/O with nothing to protect.
/// The project defaults to `MainActor` isolation, which would otherwise give
/// this type an isolated `deinit` that traps when an instance is released off
/// the main queue.
nonisolated class PhotoStorageService {
    static let shared = PhotoStorageService()

    /// Not `private` so tests can substitute a subclassed fake, the same way
    /// `WeatherService` and `AirQualityService` are faked. App code should
    /// still go through `.shared`.
    init() {}

    /// Directory for storing log photos
    private var photosDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let photosPath = documentsPath.appendingPathComponent("LogPhotos", isDirectory: true)

        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: photosPath.path) {
            try? FileManager.default.createDirectory(at: photosPath, withIntermediateDirectories: true)
        }

        return photosPath
    }

    /// Save a UIImage to disk and return its file URL
    func savePhoto(_ image: UIImage) -> URL? {
        let filename = "\(UUID().uuidString).jpg"
        let fileURL = photosDirectory.appendingPathComponent(filename)

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ Failed to convert image to JPEG data")
            return nil
        }

        do {
            try imageData.write(to: fileURL)
            print("✅ Photo saved: \(fileURL.lastPathComponent)")
            return fileURL
        } catch {
            print("❌ Failed to save photo: \(error)")
            return nil
        }
    }

    /// Load a UIImage from a file URL
    func loadPhoto(from url: URL) -> UIImage? {
        guard let imageData = try? Data(contentsOf: url),
              let image = UIImage(data: imageData) else {
            print("❌ Failed to load photo from: \(url.lastPathComponent)")
            return nil
        }
        return image
    }

    /// Delete a photo file
    func deletePhoto(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            print("✅ Photo deleted: \(url.lastPathComponent)")
        } catch {
            print("❌ Failed to delete photo: \(error)")
        }
    }

    /// Delete all photos for a specific log (cleanup)
    func deletePhotos(at urls: [URL]) {
        for url in urls {
            deletePhoto(at: url)
        }
    }
}
