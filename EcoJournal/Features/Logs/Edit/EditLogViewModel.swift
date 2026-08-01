//
//  EditLogViewModel.swift
//  EcoJournal
//
//  Business logic extracted from EditLogView: draft state, GPS refresh,
//  weather refresh, save/delete, and photo soft-deletion. The view keeps only
//  presentation and its own alert/sheet flags.
//

import Foundation
import SwiftData
import CoreLocation
import UIKit
internal import Combine

@MainActor
final class EditLogViewModel: ObservableObject {
    // MARK: - Draft State

    @Published var editedTitle: String
    @Published var editedNotes: String
    @Published var editedPhotoURLs: [URL]
    @Published var editedLatitude: Double?
    @Published var editedLongitude: Double?
    @Published var editedAltitude: Double?

    /// Photos marked for deletion but not yet committed — they stay on disk
    /// until `saveChanges()` runs, so the user can undo.
    @Published var softDeletedPhotoURLs: Set<URL> = []

    // MARK: - Async / UI State

    @Published var isRefreshingGPS = false
    @Published var isRefreshingWeather = false
    @Published var weatherRefreshError: String?
    @Published var deleteConfirmationText = ""

    /// Set when the view should dismiss. The view model never dismisses
    /// directly — that stays the view's job.
    @Published var shouldDismiss = false

    // MARK: - Dependencies

    let log: Log
    let journal: Journal
    let locationManager: LocationManager
    private let weatherService: WeatherService
    private let airQualityService: AirQualityService
    private let photoStorage: PhotoStorageService
    private let modelContext: ModelContext
    private let weatherFetchTimeoutSeconds: TimeInterval
    private let gpsPollInterval: TimeInterval
    private let gpsMaxAttempts: Int

    private var gpsTask: Task<Void, Never>?
    private var weatherTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        log: Log,
        journal: Journal,
        modelContext: ModelContext,
        locationManager: LocationManager,
        weatherService: WeatherService? = nil,
        airQualityService: AirQualityService? = nil,
        photoStorage: PhotoStorageService? = nil,
        weatherFetchTimeoutSeconds: TimeInterval = 10,
        gpsPollInterval: TimeInterval = 0.5,
        gpsMaxAttempts: Int = 20
    ) {
        self.log = log
        self.journal = journal
        self.modelContext = modelContext
        self.locationManager = locationManager
        self.weatherFetchTimeoutSeconds = weatherFetchTimeoutSeconds
        self.gpsPollInterval = gpsPollInterval
        self.gpsMaxAttempts = gpsMaxAttempts

        // Read API key from Info.plist (populated by Config.xcconfig locally or Xcode Cloud environment variable)
        let apiKey = Bundle.main.infoDictionary?["WEATHER_API_KEY"] as? String ?? ""
        self.weatherService = weatherService ?? WeatherService(apiKey: apiKey)
        self.airQualityService = airQualityService ?? AirQualityService(apiKey: apiKey)
        self.photoStorage = photoStorage ?? .shared

        // Pre-populate editable fields from the log
        editedTitle = log.title
        editedNotes = log.notes
        editedPhotoURLs = log.mediaURLs
        editedLatitude = log.latitude
        editedLongitude = log.longitude
        editedAltitude = log.altitude
    }

    deinit {
        gpsTask?.cancel()
        weatherTask?.cancel()
    }

    // MARK: - Computed Properties

    var isValid: Bool {
        !editedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasUnsavedChanges: Bool {
        editedTitle != log.title ||
        editedNotes != log.notes ||
        editedPhotoURLs != log.mediaURLs ||
        !softDeletedPhotoURLs.isEmpty ||
        editedLatitude != log.latitude ||
        editedLongitude != log.longitude ||
        editedAltitude != log.altitude
    }

    var currentLocation: CLLocation? {
        guard let lat = editedLatitude, let lon = editedLongitude else { return nil }
        return CLLocation(latitude: lat, longitude: lon)
    }

    /// Photos still shown to the user — everything not soft-deleted.
    var visiblePhotoURLs: [URL] {
        editedPhotoURLs.filter { !softDeletedPhotoURLs.contains($0) }
    }

    func isSoftDeleted(_ url: URL) -> Bool {
        softDeletedPhotoURLs.contains(url)
    }

    // MARK: - GPS

    func refreshGPSCoordinates() {
        guard !isRefreshingGPS else { return }

        isRefreshingGPS = true
        locationManager.startUpdatingLocation()

        gpsTask?.cancel()
        gpsTask = Task {
            var attempts = 0
            while attempts < gpsMaxAttempts {
                try? await Task.sleep(nanoseconds: UInt64(gpsPollInterval * 1_000_000_000))

                guard !Task.isCancelled else { return }

                if let location = locationManager.location {
                    editedLatitude = location.coordinate.latitude
                    editedLongitude = location.coordinate.longitude
                    editedAltitude = location.altitude
                    isRefreshingGPS = false
                    return
                }

                if locationManager.locationError != nil {
                    isRefreshingGPS = false
                    return
                }

                attempts += 1
            }

            // Timed out without a fix
            isRefreshingGPS = false
        }
    }

    // MARK: - Weather

    func refreshWeatherData() {
        guard let lat = editedLatitude, let lon = editedLongitude else { return }

        isRefreshingWeather = true
        weatherRefreshError = nil

        weatherTask?.cancel()
        weatherTask = Task {
            do {
                let (weather, airQuality) = try await withTimeout(seconds: weatherFetchTimeoutSeconds) {
                    async let weatherData = self.weatherService.fetchWeather(latitude: lat, longitude: lon)
                    async let airQualityData = self.airQualityService.fetchAirQuality(latitude: lat, longitude: lon)
                    return try await (weatherData, airQualityData)
                }

                guard !Task.isCancelled else { return }

                log.weather = Weather(
                    condition: weather.condition,
                    temperature: weather.temperature,
                    humidity: weather.humidity,
                    windSpeed: weather.windSpeed,
                    icon: weather.icon,
                    aqi: airQuality.aqi,
                    pm25: airQuality.pm25,
                    pm10: airQuality.pm10
                )
                isRefreshingWeather = false
            } catch is OperationTimeoutError {
                guard !Task.isCancelled else { return }
                weatherRefreshError = "Weather refresh timed out"
                isRefreshingWeather = false
            } catch {
                guard !Task.isCancelled else { return }
                weatherRefreshError = error.localizedDescription
                isRefreshingWeather = false
            }
        }
    }

    // MARK: - Save & Delete

    func saveChanges() {
        // Commit soft deletions: drop them from the log and remove the files.
        let finalPhotoURLs = visiblePhotoURLs

        for url in softDeletedPhotoURLs {
            photoStorage.deletePhoto(at: url)
        }

        log.title = editedTitle
        log.notes = editedNotes
        log.mediaURLs = finalPhotoURLs
        log.latitude = editedLatitude
        log.longitude = editedLongitude
        log.altitude = editedAltitude
        journal.touch()

        try? modelContext.save()

        softDeletedPhotoURLs.removeAll()
        editedPhotoURLs = finalPhotoURLs
        shouldDismiss = true
    }

    /// Requires the user to have typed DELETE. Returns whether the log was
    /// actually deleted.
    @discardableResult
    func deleteLog() -> Bool {
        guard isDeleteConfirmed else { return false }

        modelContext.delete(log)
        try? modelContext.save()
        shouldDismiss = true
        return true
    }

    var isDeleteConfirmed: Bool {
        deleteConfirmationText.trimmingCharacters(in: .whitespaces).uppercased() == "DELETE"
    }

    // MARK: - Photo Management

    func addPhoto(_ image: UIImage) {
        guard let url = photoStorage.savePhoto(image) else { return }
        editedPhotoURLs.append(url)
    }

    func addPhotos(_ images: [UIImage]) {
        images.forEach { addPhoto($0) }
    }

    /// Marks a photo for deletion without touching disk, so it can be restored
    /// until the edit is saved.
    func softDeletePhoto(at index: Int) {
        guard index < editedPhotoURLs.count else { return }
        softDeletedPhotoURLs.insert(editedPhotoURLs[index])
    }

    func restorePhoto(at index: Int) {
        guard index < editedPhotoURLs.count else { return }
        softDeletedPhotoURLs.remove(editedPhotoURLs[index])
    }
}
