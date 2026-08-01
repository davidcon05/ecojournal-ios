//
//  FakePhotoStorageService.swift
//  EcoJournalTests
//
//  In-memory stand-in for PhotoStorageService. Unlike MockPhotoStorageService
//  (a standalone type used to test the storage contract itself), this
//  subclasses the real service so it can be injected into view models that
//  depend on the concrete type — keeping photo tests off the shared singleton
//  and off disk.
//

import Foundation
import UIKit
@testable import EcoJournal

final class FakePhotoStorageService: PhotoStorageService {
    private(set) var savedPhotos: [URL: UIImage] = [:]
    private(set) var deletedURLs: [URL] = []

    var shouldFailSave = false

    override func savePhoto(_ image: UIImage) -> URL? {
        guard !shouldFailSave else { return nil }

        let url = URL(fileURLWithPath: "/fake/photos/\(UUID().uuidString).jpg")
        savedPhotos[url] = image
        return url
    }

    override func loadPhoto(from url: URL) -> UIImage? {
        savedPhotos[url]
    }

    override func deletePhoto(at url: URL) {
        deletedURLs.append(url)
        savedPhotos.removeValue(forKey: url)
    }

    override func deletePhotos(at urls: [URL]) {
        urls.forEach { deletePhoto(at: $0) }
    }
}
