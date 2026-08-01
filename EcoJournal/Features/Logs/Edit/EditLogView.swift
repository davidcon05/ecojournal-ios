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

/// Builds the view model once the environment's `modelContext` is available,
/// then hands off to `EditLogContentView`. Same pattern as `NewLogView`.
struct EditLogView: View {
    let log: Log
    let journal: Journal

    @Environment(\.modelContext) private var modelContext

    @StateObject private var locationManager = LocationManager()
    @State private var viewModel: EditLogViewModel?

    var body: some View {
        Group {
            if let viewModel {
                EditLogContentView(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = EditLogViewModel(
                    log: log,
                    journal: journal,
                    modelContext: modelContext,
                    locationManager: locationManager
                )
            }
        }
    }
}

struct EditLogContentView: View {
    @ObservedObject var viewModel: EditLogViewModel

    @Environment(\.dismiss) private var dismiss

    private var log: Log { viewModel.log }
    private var journal: Journal { viewModel.journal }
    private var locationManager: LocationManager { viewModel.locationManager }

    // UI state
    @State private var showingDeleteConfirmation = false
    @State private var showingGPSRefreshAlert = false
    @State private var showingWeatherRefreshAlert = false
    @State private var selectedPhotoIndex: Int = 0
    @State private var showingPhotoSource = false
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var capturedImage: UIImage?
    @State private var selectedImages: [UIImage] = []
    @State private var showingUnsavedChangesAlert = false

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
        .navigationBarBackButtonHidden(viewModel.hasUnsavedChanges)
        .toolbar {
            if viewModel.hasUnsavedChanges {
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
            Button("Refresh") { viewModel.refreshWeatherData() }
        } message: {
            Text("This will replace weather from \(log.timestamp.formatted(date: .abbreviated, time: .shortened)) with current conditions at this location.")
        }
        .alert("Refresh GPS Coordinates?", isPresented: $showingGPSRefreshAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Refresh") { viewModel.refreshGPSCoordinates() }
        } message: {
            Text("This will update GPS coordinates with your current location.")
        }
        .deleteConfirmationAlert(
            isPresented: $showingDeleteConfirmation,
            confirmationText: $viewModel.deleteConfirmationText,
            onDelete: { viewModel.deleteLog() }
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
                viewModel.addPhoto(image)
                capturedImage = nil
            }
        }
        .onChange(of: selectedImages) { _, newImages in
            if !newImages.isEmpty {
                viewModel.addPhotos(newImages)
                selectedImages = []
            }
        }
        .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss { dismiss() }
        }
    }

    /// Audio memos live on the log itself, so they are edited in place rather
    /// than staged as draft state.
    private var audioMemosBinding: Binding<[AudioMemo]> {
        Binding(
            get: { log.audioMemos },
            set: { log.audioMemos = $0 }
        )
    }

    // MARK: - Main Sections

    @ViewBuilder
    private var heroSection: some View {
        if !viewModel.editedPhotoURLs.isEmpty {
            HeroPhotoSection(
                photoURLs: viewModel.editedPhotoURLs,
                selectedPhotoIndex: min(selectedPhotoIndex, viewModel.editedPhotoURLs.count - 1),
                location: viewModel.currentLocation,
                altitude: viewModel.editedAltitude,
                mode: .editable,
                showGradientOverlay: false,
                showMetadata: false,
                softDeletedPhotoURLs: viewModel.softDeletedPhotoURLs,
                onPhotoSelect: { index in
                    selectedPhotoIndex = index
                },
                onAddPhoto: {
                    showingPhotoSource = true
                },
                onDeletePhoto: { index in
                    viewModel.softDeletePhoto(at: index)
                },
                onRestorePhoto: { index in
                    viewModel.restorePhoto(at: index)
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
                Button(action: { viewModel.saveChanges() }) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                        Text("Save Changes")
                            .font(.display(18, weight: .bold))
                    }
                    .foregroundColor(.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(viewModel.isValid ? Color.primaryColor : Color.outlineVariant)
                    .cornerRadius(12)
                    .shadow(color: Color.primaryColor.opacity(viewModel.isValid ? 0.2 : 0), radius: 8, x: 0, y: 4)
                }
                .disabled(!viewModel.isValid)
                .scaleEffect(viewModel.isValid ? 1.0 : 0.98)
                .animation(.easeInOut(duration: 0.2), value: viewModel.isValid)
                .accessibilityIdentifier(EditLogAccessibilityIdentifiers.saveButton)

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
                .accessibilityIdentifier(EditLogAccessibilityIdentifiers.deleteButton)
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

            TextField("Enter log title...", text: $viewModel.editedTitle)
                .font(.body(16, weight: .semibold))
                .textFieldStyle(.plain)
                .padding(16)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(viewModel.editedTitle.isEmpty ? Color.error.opacity(0.5) : Color.outlineVariant, lineWidth: 1)
                )
                .accessibilityIdentifier(EditLogAccessibilityIdentifiers.titleField)
        }
    }

    private var bentoGrid: some View {
        VStack(spacing: 16) {
            if viewModel.editedPhotoURLs.isEmpty {
                PhotoGalleryView(photoURLs: $viewModel.editedPhotoURLs)
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

            TextField("Enter your observations...", text: $viewModel.editedNotes, axis: .vertical)
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
                .accessibilityIdentifier(EditLogAccessibilityIdentifiers.notesField)
        }
    }

    private var telemetrySection: some View {
        VStack(spacing: 16) {
            GPSTelemetryCard(
                location: viewModel.currentLocation,
                isLoading: viewModel.isRefreshingGPS,
                error: nil,
                onRefresh: {
                    showingGPSRefreshAlert = true
                }
            )
            .accessibilityIdentifier(EditLogAccessibilityIdentifiers.gpsTelemetryCard)

            VStack(alignment: .leading, spacing: 8) {
                WeatherDataCard(
                    weather: log.weather,
                    location: viewModel.currentLocation,
                    isLoading: viewModel.isRefreshingWeather,
                    error: viewModel.weatherRefreshError,
                    onRefresh: {
                        showingWeatherRefreshAlert = true
                    }
                )
                .accessibilityIdentifier(EditLogAccessibilityIdentifiers.weatherCard)

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
