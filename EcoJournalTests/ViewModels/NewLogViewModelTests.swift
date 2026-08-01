//
//  NewLogViewModelTests.swift
//  EcoJournalTests
//
//  Created by David Contreras on 5/23/26.
//

import XCTest
import CoreLocation
import SwiftData
import UIKit
@testable import EcoJournal

@MainActor
final class NewLogViewModelTests: XCTestCase {
    var sut: NewLogViewModel!
    var testJournal: Journal!
    var testModelContext: ModelContext!
    var mockLocationManager: FakeLocationManager!
    var mockWeatherService: MockWeatherService!
    var mockAirQualityService: MockAirQualityService!
    var fakePhotoStorage: FakePhotoStorageService!

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Create in-memory model context for testing
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Journal.self, Log.self, AudioMemo.self, configurations: config)
        testModelContext = container.mainContext

        // Create test journal and save it
        testJournal = Journal(name: "Test Journal")
        testModelContext.insert(testJournal)
        try testModelContext.save()

        // Create mock services
        mockLocationManager = FakeLocationManager()
        mockWeatherService = MockWeatherService()
        mockAirQualityService = MockAirQualityService()
        fakePhotoStorage = FakePhotoStorageService()

        // Initialize system under test
        sut = NewLogViewModel(
            journal: testJournal,
            modelContext: testModelContext,
            locationManager: mockLocationManager,
            weatherService: mockWeatherService,
            airQualityService: mockAirQualityService,
            photoStorage: fakePhotoStorage
        )
    }

    override func tearDownWithError() throws {
        sut = nil
        testJournal = nil
        testModelContext = nil
        mockLocationManager = nil
        mockWeatherService = nil
        mockAirQualityService = nil
        fakePhotoStorage = nil
        try super.tearDownWithError()
    }

    // MARK: - Initialization Tests

    func testInitialization_SetsPropertiesCorrectly() {
        XCTAssertEqual(sut.title, "")
        XCTAssertEqual(sut.notes, "")
        XCTAssertTrue(sut.photoURLs.isEmpty)
        XCTAssertTrue(sut.audioMemos.isEmpty)
        XCTAssertNil(sut.currentWeather)
        XCTAssertNil(sut.weatherError)
        XCTAssertFalse(sut.isLoadingWeather)
        XCTAssertEqual(sut.selectedPhotoIndex, 0)
    }

    // MARK: - Critical Fix Validation

    func testModelContext_UsesSameContextAsJournal() {
        // This test validates the iOS 26.5 crash fix
        // ViewModel MUST use same ModelContext as the journal to avoid cross-context issues
        XCTAssertTrue(sut.modelContext === testModelContext,
                     "ViewModel must use the same ModelContext as the journal to prevent cross-context crashes on iOS 26.5")
    }

    // MARK: - Validation Tests

    func testIsValid_WithEmptyTitle_ReturnsFalse() {
        sut.title = ""
        XCTAssertFalse(sut.isValid)
    }

    func testIsValid_WithWhitespaceOnlyTitle_ReturnsFalse() {
        sut.title = "   "
        XCTAssertFalse(sut.isValid)
    }

    func testIsValid_WithValidTitle_ReturnsTrue() {
        sut.title = "Test Log Entry"
        XCTAssertTrue(sut.isValid)
    }

    // MARK: - Photo Management Tests

    func testAddPhoto_AddsPhotoURLToArray() {
        let testImage = createTestImage(color: .red)

        sut.addPhoto(testImage)

        XCTAssertEqual(sut.photoURLs.count, 1)
    }

    func testDeletePhoto_RemovesPhotoFromArray() {
        let testImage = createTestImage(color: .blue)
        sut.addPhoto(testImage)
        XCTAssertEqual(sut.photoURLs.count, 1)

        sut.deletePhoto(at: 0)

        XCTAssertEqual(sut.photoURLs.count, 0)
    }

    func testDeletePhoto_AdjustsSelectedIndex() {
        // Add 3 photos
        for _ in 0..<3 {
            sut.addPhoto(createTestImage(color: .red))
        }
        sut.selectedPhotoIndex = 2 // Select last photo

        // Delete last photo
        sut.deletePhoto(at: 2)

        XCTAssertEqual(sut.selectedPhotoIndex, 1)
    }

    func testDeletePhoto_WithInvalidIndex_DoesNotCrash() {
        sut.addPhoto(createTestImage(color: .green))

        sut.deletePhoto(at: 10)

        XCTAssertEqual(sut.photoURLs.count, 1)
    }

    // MARK: - Save Logic Tests

    func testSaveLog_WithEmptyTitle_SetsError() {
        sut.title = ""
        sut.notes = "Test notes"

        sut.saveLog()

        XCTAssertNotNil(sut.weatherError)
        XCTAssertEqual(sut.weatherError, "Title is required")
    }

    // Weather-fetch, retry, and saveLog() success-path tests (GPS present/absent,
    // audio memos, journal touch) live in NewLogViewModelSwiftTestingTests.swift,
    // written with Swift Testing rather than XCTest.

    // MARK: - Reset Tests

    func testResetForm_ClearsAllFields() {
        sut.title = "Test Title"
        sut.notes = "Test Notes"
        sut.selectedPhotoIndex = 5
        sut.currentWeather = Weather(
            condition: "Clear",
            temperature: 72.0,
            humidity: 50,
            windSpeed: 5.0,
            icon: "01d"
        )

        sut.resetForm()

        XCTAssertEqual(sut.title, "")
        XCTAssertEqual(sut.notes, "")
        XCTAssertTrue(sut.photoURLs.isEmpty)
        XCTAssertTrue(sut.audioMemos.isEmpty)
        XCTAssertNil(sut.currentWeather)
        XCTAssertNil(sut.weatherError)
        XCTAssertEqual(sut.selectedPhotoIndex, 0)
    }

    // MARK: - Helper Methods

    private func createTestImage(color: UIColor, size: CGSize = CGSize(width: 100, height: 100)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - Integration Test Notes
//
// Full integration tests for SwiftData save operations (with photos, audio, location, weather)
// are intentionally NOT included in unit tests due to ModelContext lifecycle complexity.
//
// These scenarios are covered by:
// 1. UI Tests (EcoJournalUITests/NewLogTests.swift) - Full end-to-end testing
// 2. Manual testing on physical devices and simulators
//
// The critical fix (using shared ModelContext instead of isolated one) is validated
// by testModelContext_UsesSameContextAsJournal() which prevents iOS 26.5 crashes.
