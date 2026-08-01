//
//  NewLogViewModel.swift
//  EcoJournal
//
//  Created by David Contreras on 5/23/26.
//

import SwiftUI
import SwiftData
import CoreLocation
import UIKit
internal import Combine

@MainActor
final class NewLogViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var title = ""
    @Published var notes = ""
    @Published var photoURLs: [URL] = []
    @Published var audioMemos: [AudioMemo] = []
    @Published var currentWeather: Weather?
    @Published var weatherError: String?
    @Published var isLoadingWeather = false
    @Published var selectedPhotoIndex: Int = 0
    @Published var showingSaveConfirmation = false
    @Published var showingPhotoSource = false
    @Published var showingCamera = false
    @Published var showingPhotoPicker = false
    @Published var capturedImage: UIImage?
    @Published var selectedImages: [UIImage] = []

    // MARK: - Dependencies
    let journal: Journal
    let locationManager: LocationManager
    private let weatherService: WeatherService
    private let airQualityService: AirQualityService
    private let photoStorage: PhotoStorageService
    internal let modelContext: ModelContext  // internal for testing
    private let weatherFetchTimeoutSeconds: TimeInterval

    private var weatherTask: Task<Void, Never>?

    // MARK: - Initialization
    init(
        journal: Journal,
        modelContext: ModelContext,
        locationManager: LocationManager,
        weatherService: WeatherService? = nil,
        airQualityService: AirQualityService? = nil,
        photoStorage: PhotoStorageService? = nil,
        weatherFetchTimeoutSeconds: TimeInterval = 10
    ) {
        self.journal = journal
        self.modelContext = modelContext
        self.locationManager = locationManager
        self.weatherFetchTimeoutSeconds = weatherFetchTimeoutSeconds

        // Read API key from Info.plist (populated by Config.xcconfig locally or Xcode Cloud environment variable)
        let apiKey = Bundle.main.infoDictionary?["WEATHER_API_KEY"] as? String ?? ""
        self.weatherService = weatherService ?? WeatherService(apiKey: apiKey)
        self.airQualityService = airQualityService ?? AirQualityService(apiKey: apiKey)
        self.photoStorage = photoStorage ?? .shared
    }

    deinit {
        weatherTask?.cancel()
    }

    // MARK: - Computed Properties
    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Location & Weather
    func startLocationServices() {
        locationManager.requestPermission()
        locationManager.startUpdatingLocation()
    }

    func stopLocationServices() {
        locationManager.stopUpdatingLocation()
    }

    func fetchWeatherIfNeeded(for location: CLLocation) {
        guard currentWeather == nil, !isLoadingWeather else { return }
        fetchWeatherWithTimeout(for: location)
    }

    private func fetchWeatherWithTimeout(for location: CLLocation) {
        // Cancel any existing weather fetch
        weatherTask?.cancel()

        isLoadingWeather = true
        weatherError = nil

        weatherTask = Task {
            do {
                // Fetch weather and air quality concurrently with 10 second timeout
                let (weather, airQuality) = try await withTimeout(seconds: weatherFetchTimeoutSeconds) {
                    async let weatherData = self.weatherService.fetchWeather(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude
                    )

                    async let airQualityData = self.airQualityService.fetchAirQuality(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude
                    )

                    return try await (weatherData, airQualityData)
                }

                // Check if task was cancelled
                guard !Task.isCancelled else { return }

                // Combine weather and air quality data
                let combinedWeather = Weather(
                    condition: weather.condition,
                    temperature: weather.temperature,
                    humidity: weather.humidity,
                    windSpeed: weather.windSpeed,
                    icon: weather.icon,
                    aqi: airQuality.aqi,
                    pm25: airQuality.pm25,
                    pm10: airQuality.pm10
                )

                await MainActor.run {
                    currentWeather = combinedWeather
                    isLoadingWeather = false
                }
            } catch is TimeoutError {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    weatherError = "Weather fetch timed out"
                    isLoadingWeather = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    weatherError = error.localizedDescription
                    isLoadingWeather = false
                }
            }
        }
    }

    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Add the actual operation
            group.addTask {
                try await operation()
            }

            // Add timeout task
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw TimeoutError(message: "Operation timed out after \(seconds) seconds")
            }

            // Return the first one that completes (success or timeout)
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    func retryWeatherFetch() {
        guard let location = locationManager.location else { return }
        currentWeather = nil
        weatherError = nil
        fetchWeatherWithTimeout(for: location)
    }

    // MARK: - Photo Management
    func addPhoto(_ image: UIImage) {
        guard let url = photoStorage.savePhoto(image) else { return }
        photoURLs.append(url)
    }

    func deletePhoto(at index: Int) {
        guard index < photoURLs.count else { return }
        let url = photoURLs[index]

        // Remove from array
        photoURLs.remove(at: index)

        // Delete file from disk
        photoStorage.deletePhoto(at: url)

        // Adjust selected index if needed
        if selectedPhotoIndex >= photoURLs.count {
            selectedPhotoIndex = max(0, photoURLs.count - 1)
        }
    }

    // MARK: - Save Logic
    func saveLog() {
        guard isValid else {
            weatherError = "Title is required"
            return
        }

        do {
            // Create new Log with all captured data
            let log = Log(
                title: title,
                notes: notes,
                mediaURLs: photoURLs
            )

            // Add GPS coordinates
            if let location = locationManager.location {
                log.latitude = location.coordinate.latitude
                log.longitude = location.coordinate.longitude
                log.altitude = location.altitude
            }

            // Add weather data
            log.weather = currentWeather

            // Add audio memos
            for memo in audioMemos {
                memo.log = log
                log.audioMemos.append(memo)
                modelContext.insert(memo)
            }

            // Associate with journal
            log.journal = journal

            // Save to SwiftData
            modelContext.insert(log)
            try modelContext.save()

            // Update journal's lastModified
            journal.touch()
            try modelContext.save()

            // Dismiss keyboard before showing alert (only in UI environment, not unit tests)
            if UIApplication.shared.connectedScenes.first != nil {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }

            showingSaveConfirmation = true
        } catch {
            weatherError = "Failed to save log: \(error.localizedDescription)"
        }
    }

    // MARK: - Reset
    func resetForm() {
        title = ""
        notes = ""
        photoURLs = []
        audioMemos = []
        currentWeather = nil
        weatherError = nil
        isLoadingWeather = false
        weatherTask?.cancel()
        weatherTask = nil
        selectedPhotoIndex = 0
    }

    // MARK: - Errors
    enum ValidationError: LocalizedError {
        case emptyTitle

        var errorDescription: String? {
            switch self {
            case .emptyTitle:
                return "Title is required"
            }
        }
    }

    struct TimeoutError: Error {
        let message: String
    }
}
