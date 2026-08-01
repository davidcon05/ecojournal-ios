//
//  LogDetailViewModel.swift
//  EcoJournal
//
//  Business logic extracted from LogDetailView: the weather retry for entries
//  saved without it, delete confirmation, audio playback toggling, and the
//  small display-mapping helpers.
//

import Foundation
import SwiftData
internal import Combine

@MainActor
final class LogDetailViewModel: ObservableObject {
    // MARK: - State

    @Published var isRefreshingWeather = false
    @Published var weatherRefreshError: String?
    @Published var deleteConfirmationText = ""
    @Published var playingMemoId: UUID?

    /// Set when the view should dismiss. The view owns the actual dismissal.
    @Published var shouldDismiss = false

    // MARK: - Dependencies

    let log: Log
    private let audioService: AudioRecorderService
    private let weatherService: WeatherService
    private let airQualityService: AirQualityService
    private let modelContext: ModelContext
    private let weatherFetchTimeoutSeconds: TimeInterval

    private var weatherTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        log: Log,
        modelContext: ModelContext,
        audioService: AudioRecorderService,
        weatherService: WeatherService? = nil,
        airQualityService: AirQualityService? = nil,
        weatherFetchTimeoutSeconds: TimeInterval = 10
    ) {
        self.log = log
        self.modelContext = modelContext
        self.audioService = audioService
        self.weatherFetchTimeoutSeconds = weatherFetchTimeoutSeconds

        // Read API key from Info.plist (populated by Config.xcconfig locally or Xcode Cloud environment variable)
        let apiKey = Bundle.main.infoDictionary?["WEATHER_API_KEY"] as? String ?? ""
        self.weatherService = weatherService ?? WeatherService(apiKey: apiKey)
        self.airQualityService = airQualityService ?? AirQualityService(apiKey: apiKey)
    }

    deinit {
        weatherTask?.cancel()
    }

    // MARK: - Computed Properties

    var hasGPSData: Bool {
        log.latitude != nil && log.longitude != nil
    }

    /// Weather can only be retried for entries that recorded a location.
    var canFetchWeather: Bool {
        hasGPSData && log.weather == nil
    }

    var weatherTimeMismatchMessage: String {
        let createdAt = log.timestamp.formatted(date: .abbreviated, time: .shortened)
        let now = Date().formatted(date: .abbreviated, time: .shortened)
        return "This entry was created \(createdAt). Weather isn't available for that moment — getting weather now will use current conditions as of \(now) instead, not conditions from when the entry was made."
    }

    func aqiLabel(_ aqi: Int) -> String {
        switch aqi {
        case 1: return "1 Good"
        case 2: return "2 Fair"
        case 3: return "3 Moderate"
        case 4: return "4 Poor"
        case 5: return "5 Very Poor"
        default: return "\(aqi)"
        }
    }

    // MARK: - Weather

    func fetchWeatherForLog() {
        guard let lat = log.latitude, let lon = log.longitude else { return }
        guard !isRefreshingWeather else { return }

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
                try? modelContext.save()
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

    // MARK: - Delete

    var isDeleteConfirmed: Bool {
        deleteConfirmationText.trimmingCharacters(in: .whitespaces).uppercased() == "DELETE"
    }

    @discardableResult
    func deleteLog() -> Bool {
        guard isDeleteConfirmed else { return false }

        modelContext.delete(log)
        try? modelContext.save()
        shouldDismiss = true
        return true
    }

    // MARK: - Audio Playback

    /// Tapping the memo that's already playing stops it; tapping any other
    /// memo stops the current one and starts that memo instead.
    func toggleAudio(for memo: AudioMemo) {
        audioService.stopPlayback()

        if playingMemoId == memo.id {
            playingMemoId = nil
        } else {
            audioService.playAudio(from: memo.audioURL)
            playingMemoId = memo.id
        }
    }
}
