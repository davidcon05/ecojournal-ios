//
//  EditLogView.swift
//  EcoJournal
//
//  Created by David Contreras on 5/10/26.
//

import SwiftUI
import UIKit
import CoreLocation
import SwiftData

struct EditLogView: View {
    let log: Log
    let journal: Journal

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let weatherService: WeatherService
    private let airQualityService: AirQualityService

    @StateObject private var locationManager = LocationManager()

    // Editable state
    @State private var editedTitle: String
    @State private var editedNotes: String
    @State private var editedPhotoURLs: [URL]
    @State private var editedLatitude: Double?
    @State private var editedLongitude: Double?
    @State private var editedAltitude: Double?

    // Draft state tracking
    @State private var softDeletedPhotoURLs: Set<URL> = []

    // UI state
    @State private var showingDeleteConfirmation = false
    @State private var deleteConfirmationText = ""
    @State private var showingGPSRefreshAlert = false
    @State private var showingWeatherRefreshAlert = false
    @State private var isRefreshingGPS = false
    @State private var isRefreshingWeather = false
    @State private var weatherRefreshError: String?
    @State private var selectedPhotoIndex: Int = 0
    @State private var showingPhotoSource = false
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var capturedImage: UIImage?
    @State private var selectedImages: [UIImage] = []
    @State private var showingUnsavedChangesAlert = false

    private let photoStorage = PhotoStorageService.shared

    init(log: Log, journal: Journal) {
        self.log = log
        self.journal = journal

        // Initialize services - Read API key from Info.plist (populated by Config.xcconfig locally or Xcode Cloud environment variable)
        let apiKey = Bundle.main.infoDictionary?["WEATHER_API_KEY"] as? String ?? ""
        self.weatherService = WeatherService(apiKey: apiKey)
        self.airQualityService = AirQualityService(apiKey: apiKey)

        // Pre-populate editable fields
        _editedTitle = State(initialValue: log.title)
        _editedNotes = State(initialValue: log.notes)
        _editedPhotoURLs = State(initialValue: log.mediaURLs)
        _editedLatitude = State(initialValue: log.latitude)
        _editedLongitude = State(initialValue: log.longitude)
        _editedAltitude = State(initialValue: log.altitude)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                    formContent
                        .padding(.horizontal, 24)
                }
                .padding(.top, 24)
                .padding(.bottom, 180)
            }
            .background(Color.background)

            actionButtons
        }
        .navigationTitle("Edit Log")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(hasUnsavedChanges)
        .toolbar {
            if hasUnsavedChanges {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingUnsavedChangesAlert = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                }
            }
        }
        .alert("Unsaved Changes", isPresented: $showingUnsavedChangesAlert) {
            Button("Discard Changes", role: .destructive) {
                dismiss()
            }
            Button("Keep Editing", role: .cancel) { }
        } message: {
            Text("You have unsaved changes. Are you sure you want to discard them?")
        }
        .alert("Refresh Weather Data?", isPresented: $showingWeatherRefreshAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Refresh") { refreshWeatherData() }
        } message: {
            Text("This will replace weather from \(log.timestamp.formatted(date: .abbreviated, time: .shortened)) with current conditions at this location.")
        }
        .alert("Refresh GPS Coordinates?", isPresented: $showingGPSRefreshAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Refresh") { refreshGPSCoordinates() }
        } message: {
            Text("This will update GPS coordinates with your current location.")
        }
        .deleteConfirmationAlert(
            isPresented: $showingDeleteConfirmation,
            confirmationText: $deleteConfirmationText,
            onDelete: deleteLog
        )
        .confirmationDialog("Add Photo", isPresented: $showingPhotoSource, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { showingCamera = true }
            }
            Button("Choose from Library") { showingPhotoPicker = true }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingCamera) {
            CameraPickerRepresentable(selectedImage: $capturedImage, sourceType: .camera)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showingPhotoPicker) {
            PhotoPickerRepresentable(selectedImages: $selectedImages)
                .ignoresSafeArea()
        }
        .onChange(of: capturedImage) { _, newImage in
            if let image = newImage {
                addPhoto(image)
                capturedImage = nil
            }
        }
        .onChange(of: selectedImages) { _, newImages in
            if !newImages.isEmpty {
                addPhotos(newImages)
                selectedImages = []
            }
        }
    }

    // MARK: - Main Sections

    @ViewBuilder
    private var heroSection: some View {
        if !editedPhotoURLs.isEmpty {
            HeroPhotoSection(
                photoURLs: editedPhotoURLs,
                selectedPhotoIndex: min(selectedPhotoIndex, editedPhotoURLs.count - 1),
                location: currentLocation,
                altitude: editedAltitude,
                mode: .editable,
                showGradientOverlay: false,
                showMetadata: false,
                softDeletedPhotoURLs: softDeletedPhotoURLs,
                onPhotoSelect: { index in
                    selectedPhotoIndex = index
                },
                onAddPhoto: {
                    showingPhotoSource = true
                },
                onDeletePhoto: { index in
                    deletePhoto(at: index)
                },
                onRestorePhoto: { index in
                    restorePhoto(at: index)
                }
            )
        }
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 32) {
            sessionHeader
            titleField
            bentoGrid
            fieldNotesSection
            telemetrySection
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.background.opacity(0), Color.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 20)

            VStack(spacing: 12) {
                Button(action: saveChanges) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                        Text("Save Changes")
                            .font(.display(18, weight: .bold))
                    }
                    .foregroundColor(.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(isValid ? Color.primaryColor : Color.outlineVariant)
                    .cornerRadius(12)
                    .shadow(color: Color.primaryColor.opacity(isValid ? 0.2 : 0), radius: 8, x: 0, y: 4)
                }
                .disabled(!isValid)
                .scaleEffect(isValid ? 1.0 : 0.98)
                .animation(.easeInOut(duration: 0.2), value: isValid)

                Button(action: { showingDeleteConfirmation = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 18))
                        Text("Delete Log Entry")
                            .font(.display(16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.red)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .background(Color.background)
        }
    }

    // MARK: - Form Sections

    private var sessionHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Edit Entry")
                .font(.label(10, weight: .bold))
                .foregroundColor(.tertiary)
                .tracking(1.5)

            Text("EDIT LOG ENTRY")
                .font(.display(24, weight: .black))
                .foregroundColor(.onBackground)
                .tracking(-0.5)

            Text("Created: \(log.timestamp.formatted(date: .abbreviated, time: .shortened))")
                .font(.body(14))
                .foregroundColor(.onSurfaceVariant)
                .padding(.top, 4)
        }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TITLE (REQUIRED)")
                .font(.label(10, weight: .bold))
                .foregroundColor(.tertiary)
                .tracking(1.5)

            TextField("Enter log title...", text: $editedTitle)
                .font(.body(16, weight: .semibold))
                .textFieldStyle(.plain)
                .padding(16)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(editedTitle.isEmpty ? Color.error.opacity(0.5) : Color.outlineVariant, lineWidth: 1)
                )
        }
    }

    private var bentoGrid: some View {
        VStack(spacing: 16) {
            if editedPhotoURLs.isEmpty {
                PhotoGalleryView(photoURLs: $editedPhotoURLs)
            }
            MultiAudioMemoView(audioMemos: audioMemosBinding)
        }
    }

    private var fieldNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FIELD NOTES (OPTIONAL)")
                .font(.label(10, weight: .bold))
                .foregroundColor(.tertiary)
                .tracking(1.5)

            TextField("Enter your observations...", text: $editedNotes, axis: .vertical)
                .font(.body(15))
                .lineLimit(6...10)
                .textFieldStyle(.plain)
                .padding(16)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.outlineVariant, lineWidth: 1)
                )
        }
    }

    private var telemetrySection: some View {
        VStack(spacing: 16) {
            GPSTelemetryCard(
                location: currentLocation,
                isLoading: isRefreshingGPS,
                error: nil,
                onRefresh: {
                    showingGPSRefreshAlert = true
                }
            )

            VStack(alignment: .leading, spacing: 8) {
                WeatherDataCard(
                    weather: log.weather,
                    location: currentLocation,
                    isLoading: isRefreshingWeather,
                    error: weatherRefreshError,
                    onRefresh: {
                        showingWeatherRefreshAlert = true
                    }
                )

                if log.weather != nil {
                    Text("CAPTURED AT \(log.timestamp.formatted(date: .abbreviated, time: .shortened))")
                        .font(.label(10, weight: .bold))
                        .foregroundColor(.tertiary)
                        .tracking(1.5)
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var isValid: Bool {
        !editedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasUnsavedChanges: Bool {
        editedTitle != log.title ||
        editedNotes != log.notes ||
        editedPhotoURLs != log.mediaURLs ||
        !softDeletedPhotoURLs.isEmpty ||
        editedLatitude != log.latitude ||
        editedLongitude != log.longitude ||
        editedAltitude != log.altitude
    }

    private var currentLocation: CLLocation? {
        guard let lat = editedLatitude, let lon = editedLongitude else { return nil }
        return CLLocation(latitude: lat, longitude: lon)
    }

    private var audioMemosBinding: Binding<[AudioMemo]> {
        Binding(
            get: { log.audioMemos },
            set: { log.audioMemos = $0 }
        )
    }

    // MARK: - Action Handlers

    private func refreshGPSCoordinates() {
        isRefreshingGPS = true
        locationManager.startUpdatingLocation()

        // Wait for location update with timeout
        Task {
            var attempts = 0
            while attempts < 20 { // 10 seconds max (20 * 0.5s)
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                if let location = locationManager.location {
                    await MainActor.run {
                        editedLatitude = location.coordinate.latitude
                        editedLongitude = location.coordinate.longitude
                        editedAltitude = location.altitude
                        isRefreshingGPS = false
                    }
                    return
                }

                if locationManager.locationError != nil {
                    await MainActor.run {
                        isRefreshingGPS = false
                    }
                    return
                }

                attempts += 1
            }

            // Timeout
            await MainActor.run {
                isRefreshingGPS = false
            }
        }
    }

    private func refreshWeatherData() {
        guard let lat = editedLatitude, let lon = editedLongitude else { return }

        isRefreshingWeather = true
        weatherRefreshError = nil

        Task {
            do {
                let location = CLLocation(latitude: lat, longitude: lon)

                // Fetch weather and air quality concurrently with timeout
                let (weather, airQuality) = try await withTimeout(seconds: 10) {
                    async let weatherData = weatherService.fetchWeather(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude
                    )

                    async let airQualityData = airQualityService.fetchAirQuality(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude
                    )

                    return try await (weatherData, airQualityData)
                }

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
                    log.weather = combinedWeather
                    isRefreshingWeather = false
                }
            } catch is TimeoutError {
                await MainActor.run {
                    weatherRefreshError = "Weather refresh timed out"
                    isRefreshingWeather = false
                }
            } catch {
                await MainActor.run {
                    weatherRefreshError = error.localizedDescription
                    isRefreshingWeather = false
                }
            }
        }
    }

    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    struct TimeoutError: Error {}

    private func saveChanges() {
        // Apply soft deletions - filter out soft-deleted photos
        let finalPhotoURLs = editedPhotoURLs.filter { !softDeletedPhotoURLs.contains($0) }

        // Delete soft-deleted photos from disk
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
        dismiss()
    }

    private func deleteLog() {
        guard deleteConfirmationText.trimmingCharacters(in: .whitespaces).uppercased() == "DELETE" else { return }

        modelContext.delete(log)
        try? modelContext.save()
        dismiss()
    }

    // MARK: - Photo Management

    private func addPhoto(_ image: UIImage) {
        guard let url = photoStorage.savePhoto(image) else { return }
        editedPhotoURLs.append(url)
    }

    private func addPhotos(_ images: [UIImage]) {
        for image in images {
            addPhoto(image)
        }
    }

    private func deletePhoto(at index: Int) {
        guard index < editedPhotoURLs.count else { return }
        let url = editedPhotoURLs[index]

        // Soft delete - just mark as deleted with animation
        withAnimation {
            softDeletedPhotoURLs.insert(url)
        }
    }

    private func restorePhoto(at index: Int) {
        guard index < editedPhotoURLs.count else { return }
        let url = editedPhotoURLs[index]

        // Remove from soft delete set with animation
        withAnimation {
            softDeletedPhotoURLs.remove(url)
        }
    }
}

#Preview("Complete Log") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Journal.self, Log.self, AudioMemo.self, configurations: config)

    let journal = Journal(name: "Test Journal")
    let log = Log(title: "Complete Field Observation", notes: "Sample log entry with all data - GPS, weather, photos, and audio memo")
    log.latitude = 47.8597
    log.longitude = -123.9346
    log.altitude = 182.0
    log.weather = Weather(
        condition: "Clear",
        temperature: 18.5,
        humidity: 62,
        windSpeed: 3.2,
        icon: "01d",
        aqi: 1,
        pm25: 8.5,
        pm10: 12.3
    )
    // Simulate having photos and audio
    log.mediaURLs = [URL(string: "file:///photo1.jpg")!, URL(string: "file:///photo2.jpg")!]
    let memo = AudioMemo(title: "Field Notes", audioURL: URL(string: "file:///memo.m4a")!, duration: 45)
    memo.log = log
    log.audioMemos = [memo]
    journal.logs.append(log)
    container.mainContext.insert(journal)

    return NavigationStack {
        EditLogView(log: log, journal: journal)
            .modelContainer(container)
    }
}

#Preview("Minimal Log") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Journal.self, Log.self, configurations: config)

    let journal = Journal(name: "Test Journal")
    let log = Log(title: "Minimal Log Entry", notes: "Basic observation with no GPS, weather, or media data")
    // No GPS, no weather, no media
    journal.logs.append(log)
    container.mainContext.insert(journal)

    return NavigationStack {
        EditLogView(log: log, journal: journal)
            .modelContainer(container)
    }
}

#Preview("With Photos Only") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Journal.self, Log.self, configurations: config)

    let journal = Journal(name: "Test Journal")
    let log = Log(title: "Photo Observation", notes: "Photo observation - has GPS and photos but no weather")
    log.latitude = 48.1234
    log.longitude = -122.5678
    log.altitude = 250.0
    log.mediaURLs = [
        URL(string: "file:///photo1.jpg")!,
        URL(string: "file:///photo2.jpg")!,
        URL(string: "file:///photo3.jpg")!
    ]
    journal.logs.append(log)
    container.mainContext.insert(journal)

    return NavigationStack {
        EditLogView(log: log, journal: journal)
            .modelContainer(container)
    }
}

#Preview("With Audio Only") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Journal.self, Log.self, AudioMemo.self, configurations: config)

    let journal = Journal(name: "Test Journal")
    let log = Log(title: "Audio Field Memo", notes: "Audio observation - has GPS and audio memo but no weather")
    log.latitude = 47.9876
    log.longitude = -123.4321
    log.altitude = 100.0
    let memo = AudioMemo(title: "Voice Memo", audioURL: URL(string: "file:///field-memo.m4a")!, duration: 60)
    memo.log = log
    log.audioMemos = [memo]
    journal.logs.append(log)
    container.mainContext.insert(journal)

    return NavigationStack {
        EditLogView(log: log, journal: journal)
            .modelContainer(container)
    }
}

#Preview("GPS Only") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Journal.self, Log.self, configurations: config)

    let journal = Journal(name: "Test Journal")
    let log = Log(title: "GPS Location Capture", notes: "GPS-only observation - location captured but weather fetch failed")
    log.latitude = 48.0000
    log.longitude = -124.0000
    log.altitude = 350.0
    // Has GPS but no weather or media
    journal.logs.append(log)
    container.mainContext.insert(journal)

    return NavigationStack {
        EditLogView(log: log, journal: journal)
            .modelContainer(container)
    }
}

#Preview("Weather Only") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Journal.self, Log.self, configurations: config)

    let journal = Journal(name: "Test Journal")
    let log = Log(title: "Weather Observation", notes: "Weather-only observation - manually added without GPS")
    // No GPS coordinates
    log.weather = Weather(
        condition: "Cloudy",
        temperature: 15.0,
        humidity: 78,
        windSpeed: 5.5,
        icon: "04d",
        aqi: 2,
        pm25: 15.2,
        pm10: 22.1
    )
    journal.logs.append(log)
    container.mainContext.insert(journal)

    return NavigationStack {
        EditLogView(log: log, journal: journal)
            .modelContainer(container)
    }
}
