//
//  EditLogViewModelTests.swift
//  EcoJournalTests
//
//  Covers the logic extracted from EditLogView: draft state, unsaved-change
//  detection, GPS refresh, weather refresh, save/delete, and photo
//  soft-deletion.
//

import Testing
import Foundation
import CoreLocation
import SwiftData
import UIKit
@testable import EcoJournal

@MainActor
@Suite("EditLogViewModel Tests")
struct EditLogViewModelTests {
    let testContainer: ModelContainer
    let testModelContext: ModelContext
    let journal: Journal
    let log: Log
    let locationManager: FakeLocationManager
    let weatherService: MockWeatherService
    let airQualityService: MockAirQualityService
    let photoStorage: FakePhotoStorageService
    let sut: EditLogViewModel

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        testContainer = try ModelContainer(for: Journal.self, Log.self, AudioMemo.self, configurations: config)
        testModelContext = testContainer.mainContext

        journal = Journal(name: "Test Journal")
        testModelContext.insert(journal)

        log = Log(title: "Original Title", notes: "Original notes", mediaURLs: [])
        testModelContext.insert(log)
        log.journal = journal
        log.latitude = 47.6062
        log.longitude = -122.3321
        log.altitude = 50
        try testModelContext.save()

        locationManager = FakeLocationManager()
        weatherService = MockWeatherService()
        airQualityService = MockAirQualityService()
        photoStorage = FakePhotoStorageService()

        sut = EditLogViewModel(
            log: log,
            journal: journal,
            modelContext: testModelContext,
            locationManager: locationManager,
            weatherService: weatherService,
            airQualityService: airQualityService,
            photoStorage: photoStorage,
            weatherFetchTimeoutSeconds: 0.5,
            gpsPollInterval: 0.01,
            gpsMaxAttempts: 5
        )
    }

    // MARK: - Initial Draft State

    @Test("Draft state is pre-populated from the log")
    func init_prepopulatesDraftFromLog() {
        #expect(sut.editedTitle == "Original Title")
        #expect(sut.editedNotes == "Original notes")
        #expect(sut.editedLatitude == 47.6062)
        #expect(sut.editedAltitude == 50)
        #expect(sut.hasUnsavedChanges == false)
        #expect(sut.shouldDismiss == false)
    }

    // MARK: - Validation

    @Test("A title of only whitespace is invalid")
    func isValid_withWhitespaceTitle_isFalse() {
        sut.editedTitle = "   "
        #expect(sut.isValid == false)
    }

    @Test("A non-empty title is valid")
    func isValid_withText_isTrue() {
        sut.editedTitle = "Heron"
        #expect(sut.isValid == true)
    }

    // MARK: - Unsaved Changes

    @Test("Editing the title marks the draft dirty")
    func hasUnsavedChanges_afterTitleEdit_isTrue() {
        sut.editedTitle = "Changed"
        #expect(sut.hasUnsavedChanges == true)
    }

    @Test("Soft-deleting a photo marks the draft dirty")
    func hasUnsavedChanges_afterSoftDelete_isTrue() {
        sut.editedPhotoURLs = [URL(fileURLWithPath: "/fake/a.jpg")]
        sut.softDeletePhoto(at: 0)
        #expect(sut.hasUnsavedChanges == true)
    }

    @Test("Restoring the only soft-deleted photo makes the draft clean again")
    func hasUnsavedChanges_afterRestore_returnsToClean() throws {
        let url = URL(fileURLWithPath: "/fake/a.jpg")
        log.mediaURLs = [url]
        try testModelContext.save()
        let vm = makeViewModel()

        vm.softDeletePhoto(at: 0)
        #expect(vm.hasUnsavedChanges == true)

        vm.restorePhoto(at: 0)
        #expect(vm.hasUnsavedChanges == false)
    }

    // MARK: - Photo Soft Deletion

    @Test("Soft deletion hides the photo but leaves it on disk until save")
    func softDeletePhoto_hidesButKeepsFile() {
        let url = URL(fileURLWithPath: "/fake/a.jpg")
        sut.editedPhotoURLs = [url]

        sut.softDeletePhoto(at: 0)

        #expect(sut.visiblePhotoURLs.isEmpty)
        #expect(sut.isSoftDeleted(url))
        #expect(photoStorage.deletedURLs.isEmpty)
    }

    @Test("Soft deleting out of range is ignored")
    func softDeletePhoto_outOfRange_isIgnored() {
        sut.editedPhotoURLs = [URL(fileURLWithPath: "/fake/a.jpg")]

        sut.softDeletePhoto(at: 7)

        #expect(sut.softDeletedPhotoURLs.isEmpty)
    }

    @Test("addPhoto stores the image and appends its URL")
    func addPhoto_appendsSavedURL() {
        sut.addPhoto(UIImage())

        #expect(sut.editedPhotoURLs.count == 1)
        #expect(photoStorage.savedPhotos.count == 1)
    }

    @Test("addPhoto ignores an image the storage layer refuses to save")
    func addPhoto_whenSaveFails_addsNothing() {
        photoStorage.shouldFailSave = true

        sut.addPhoto(UIImage())

        #expect(sut.editedPhotoURLs.isEmpty)
    }

    @Test("addPhotos appends one URL per image")
    func addPhotos_appendsAll() {
        sut.addPhotos([UIImage(), UIImage(), UIImage()])

        #expect(sut.editedPhotoURLs.count == 3)
    }

    // MARK: - Save

    @Test("saveChanges writes the draft back to the log and requests dismissal")
    func saveChanges_appliesDraftToLog() {
        sut.editedTitle = "Updated Title"
        sut.editedNotes = "Updated notes"
        sut.editedLatitude = 10
        sut.editedLongitude = 20

        sut.saveChanges()

        #expect(log.title == "Updated Title")
        #expect(log.notes == "Updated notes")
        #expect(log.latitude == 10)
        #expect(log.longitude == 20)
        #expect(sut.shouldDismiss == true)
    }

    @Test("saveChanges deletes soft-deleted photos from storage and drops them from the log")
    func saveChanges_commitsSoftDeletions() {
        let kept = URL(fileURLWithPath: "/fake/keep.jpg")
        let removed = URL(fileURLWithPath: "/fake/remove.jpg")
        sut.editedPhotoURLs = [kept, removed]
        sut.softDeletePhoto(at: 1)

        sut.saveChanges()

        #expect(log.mediaURLs == [kept])
        #expect(photoStorage.deletedURLs == [removed])
        #expect(sut.softDeletedPhotoURLs.isEmpty)
    }

    @Test("saveChanges touches the journal's lastModified")
    func saveChanges_touchesJournal() {
        let before = journal.lastModified
        sut.editedTitle = "Updated"

        sut.saveChanges()

        #expect(journal.lastModified != before)
    }

    @Test("The draft is clean again immediately after saving")
    func saveChanges_leavesDraftClean() {
        sut.editedTitle = "Updated"

        sut.saveChanges()

        #expect(sut.hasUnsavedChanges == false)
    }

    // MARK: - Delete

    @Test("deleteLog does nothing until the user types DELETE")
    func deleteLog_withoutConfirmation_doesNothing() throws {
        sut.deleteConfirmationText = "nope"

        #expect(sut.deleteLog() == false)
        #expect(try testModelContext.fetch(FetchDescriptor<Log>()).isEmpty == false)
        #expect(sut.shouldDismiss == false)
    }

    @Test("deleteLog accepts the confirmation case-insensitively and trimmed")
    func deleteLog_withConfirmation_deletes() throws {
        sut.deleteConfirmationText = "  delete  "

        #expect(sut.deleteLog() == true)
        #expect(try testModelContext.fetch(FetchDescriptor<Log>()).isEmpty)
        #expect(sut.shouldDismiss == true)
    }

    // MARK: - GPS Refresh

    @Test("refreshGPSCoordinates adopts a new fix into the draft")
    func refreshGPS_withFix_updatesDraft() async throws {
        locationManager.simulateLocation(latitude: 1.5, longitude: 2.5, altitude: 99)

        sut.refreshGPSCoordinates()
        try await waitUntil { sut.isRefreshingGPS == false }

        #expect(sut.editedLatitude == 1.5)
        #expect(sut.editedLongitude == 2.5)
        #expect(sut.editedAltitude == 99)
        #expect(locationManager.startUpdatingLocationCallCount == 1)
    }

    @Test("refreshGPSCoordinates stops when the location manager reports an error")
    func refreshGPS_withError_stops() async throws {
        locationManager.locationError = "Location permission not granted"

        sut.refreshGPSCoordinates()
        try await waitUntil { sut.isRefreshingGPS == false }

        // Draft keeps the log's original coordinates
        #expect(sut.editedLatitude == 47.6062)
    }

    @Test("refreshGPSCoordinates gives up after its attempt budget")
    func refreshGPS_withNoFix_timesOut() async throws {
        locationManager.location = nil

        sut.refreshGPSCoordinates()
        try await waitUntil { sut.isRefreshingGPS == false }

        #expect(sut.editedLatitude == 47.6062)
    }

    // MARK: - Weather Refresh

    @Test("refreshWeatherData stores combined weather and air quality on the log")
    func refreshWeather_onSuccess_setsWeather() async throws {
        sut.refreshWeatherData()
        try await waitUntil { sut.isRefreshingWeather == false }

        #expect(log.weather?.condition == "Clear")
        #expect(log.weather?.aqi == 2)
        #expect(sut.weatherRefreshError == nil)
    }

    @Test("refreshWeatherData does nothing without coordinates")
    func refreshWeather_withoutCoordinates_doesNothing() {
        sut.editedLatitude = nil
        sut.editedLongitude = nil

        sut.refreshWeatherData()

        #expect(sut.isRefreshingWeather == false)
        #expect(weatherService.fetchWeatherCalled == false)
    }

    @Test("refreshWeatherData surfaces a service failure")
    func refreshWeather_onFailure_setsError() async throws {
        weatherService.shouldSucceed = false

        sut.refreshWeatherData()
        try await waitUntil { sut.weatherRefreshError != nil }

        #expect(sut.isRefreshingWeather == false)
    }

    @Test("refreshWeatherData reports a timeout distinctly")
    func refreshWeather_onTimeout_setsTimeoutError() async throws {
        weatherService.shouldHang = true

        sut.refreshWeatherData()
        try await waitUntil { sut.weatherRefreshError != nil }

        #expect(sut.weatherRefreshError == "Weather refresh timed out")
    }

    // MARK: - Helpers

    private func makeViewModel() -> EditLogViewModel {
        EditLogViewModel(
            log: log,
            journal: journal,
            modelContext: testModelContext,
            locationManager: locationManager,
            weatherService: weatherService,
            airQualityService: airQualityService,
            photoStorage: photoStorage,
            weatherFetchTimeoutSeconds: 0.5,
            gpsPollInterval: 0.01,
            gpsMaxAttempts: 5
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 3.0,
        condition: @escaping () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { throw WaitTimeoutError() }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    private struct WaitTimeoutError: Error {}
}
