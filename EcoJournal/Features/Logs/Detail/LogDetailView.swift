//
//  LogDetailView.swift
//  EcoJournal
//
//  Created by David Contreras on 5/19/26.
//

import SwiftUI
import CoreLocation
import SwiftData
import MapKit

struct LogDetailView: View {
    let log: Log
    let journal: Journal

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @StateObject private var audioService = AudioRecorderService()
    @State private var playingMemoId: UUID? = nil

    @State private var showingEditView = false
    @State private var showingDeleteConfirmation = false
    @State private var deleteConfirmationText = ""
    @State private var selectedPhotoIndex: Int = 0
    @State private var isMapExpanded = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSection
                contentSections
            }
        }
        .background(Color.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .navigationDestination(isPresented: $showingEditView) {
            EditLogView(log: log, journal: journal)
        }
        .deleteConfirmationAlert(
            isPresented: $showingDeleteConfirmation,
            confirmationText: $deleteConfirmationText,
            onDelete: deleteLog
        )
    }

    // MARK: - Main Sections

    private var heroSection: some View {
        HeroPhotoSection(
            photoURLs: log.mediaURLs,
            selectedPhotoIndex: selectedPhotoIndex,
            location: hasGPSData ? CLLocation(latitude: log.latitude!, longitude: log.longitude!) : nil,
            altitude: log.altitude,
            mode: .readOnly,
            showGradientOverlay: true,
            showMetadata: true,
            onPhotoSelect: { index in
                selectedPhotoIndex = index
            },
            onAddPhoto: {
                showingEditView = true
            }
        )
        .accessibilityIdentifier(LogDetailAccessibilityIdentifiers.heroPhoto)
    }

    private var contentSections: some View {
        VStack(spacing: 32) {
            titleSection

            if !log.notes.isEmpty {
                fieldNotesSection
            }

            if !log.audioMemos.isEmpty {
                fieldObservationsSection
            }

            if log.weather != nil {
                telemetryDataSection
            }

            if hasGPSData {
                locationSyncSection
            }

            actionButtons
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            VStack(spacing: 2) {
                Text("Log Details")
                    .font(.body(16, weight: .bold))
                    .foregroundColor(.onSurface)
                Text(journal.name.uppercased())
                    .font(.label(9, weight: .bold))
                    .foregroundColor(.onSurfaceVariant)
                    .tracking(1.2)
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { showingEditView = true }) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primaryColor)
            }
            .accessibilityIdentifier(LogDetailAccessibilityIdentifiers.editButton)
        }
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(log.title)
                .font(.display(28, weight: .black))
                .foregroundColor(.onBackground)
                .tracking(-0.5)
                .accessibilityIdentifier(LogDetailAccessibilityIdentifiers.titleText)

            Text(log.timestamp.formatted(date: .abbreviated, time: .shortened).uppercased())
                .font(.label(12, weight: .bold))
                .foregroundColor(.primaryColor)
                .tracking(1.5)
                .accessibilityIdentifier(LogDetailAccessibilityIdentifiers.timestampText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
    }

    // MARK: - Field Notes Section

    private var fieldNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "doc.text", title: "Field Notes")

            Text(log.notes)
                .font(.body(16))
                .foregroundColor(.onSurface)
                .lineSpacing(6)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.surfaceContainerLow)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.outlineVariant.opacity(0.3), lineWidth: 1)
                )
                .accessibilityIdentifier(LogDetailAccessibilityIdentifiers.notesText)
        }
    }

    // MARK: - Field Observations Section (Audio)

    private var fieldObservationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "waveform", title: "Field Observations")

            VStack(spacing: 12) {
                ForEach(Array(log.audioMemos.enumerated()), id: \.element.id) { index, memo in
                    AudioMemoDisplayCard(
                        memo: memo,
                        index: index + 1,
                        audioService: audioService,
                        isPlaying: playingMemoId == memo.id,
                        onPlay: {
                            playAudio(memo: memo)
                        }
                    )
                }
            }
        }
    }

    // MARK: - Telemetry Data Section (Weather)

    private var telemetryDataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "chart.line.uptrend.xyaxis", title: "Telemetry Data")

            if let weather = log.weather {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    TelemetryCard(
                        icon: "thermometer.medium",
                        label: "Temperature",
                        value: String(format: "%.1f°F", weather.temperature)
                    )

                    TelemetryCard(
                        icon: "humidity",
                        label: "Humidity",
                        value: "\(weather.humidity)%"
                    )

                    TelemetryCard(
                        icon: "wind",
                        label: "Wind Speed",
                        value: String(format: "%.1f mph", weather.windSpeed * 0.621371)
                    )

                    if let aqi = weather.aqi {
                        TelemetryCard(
                            icon: "aqi.medium",
                            label: "Air Quality",
                            value: aqiLabel(aqi)
                        )
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(LogDetailAccessibilityIdentifiers.weatherDataCard)
            }
        }
    }

    // MARK: - Location Sync Section

    private var locationSyncSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "map", title: "Location Sync")

            if let lat = log.latitude, let lon = log.longitude {
                ZStack(alignment: .topTrailing) {
                    ZStack(alignment: .bottom) {
                        // Map preview
                        Map(
                            position: .constant(.region(MKCoordinateRegion(
                                center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                                span: MKCoordinateSpan(
                                    latitudeDelta: isMapExpanded ? 0.005 : 0.01,
                                    longitudeDelta: isMapExpanded ? 0.005 : 0.01
                                )
                            )))
                        ) {
                            Marker("", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                                .tint(Color.primaryColor)
                        }
                        .mapStyle(.hybrid)
                        .frame(height: isMapExpanded ? UIScreen.main.bounds.height / 2 : 200)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.outlineVariant.opacity(0.3), lineWidth: 1)
                        )

                        // Info bar at bottom
                        HStack {
                            Text("SECTOR: FIELD")
                                .font(.label(9, weight: .bold))
                                .foregroundColor(.onSurfaceVariant)
                                .tracking(1.5)

                            Spacer()

                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.primaryColor)
                                Text("SYNCED")
                                    .font(.label(9, weight: .bold))
                                    .foregroundColor(.onSurfaceVariant)
                                    .tracking(1.2)
                            }
                        }
                        .padding(12)
                        .background(Color.surfaceContainer.opacity(0.95))
                        .cornerRadius(8, corners: [.bottomLeft, .bottomRight])
                    }

                    // Expand/Collapse button
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isMapExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isMapExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.onPrimary)
                            .frame(width: 36, height: 36)
                            .background(Color.primaryColor)
                            .cornerRadius(8)
                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .padding(12)
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(LogDetailAccessibilityIdentifiers.gpsTelemetryCard)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 16) {
            // Edit Button
            Button(action: {
                showingEditView = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 18))
                    Text("Edit Field Note")
                        .font(.body(16, weight: .bold))
                }
                .foregroundColor(.onSurface)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.surfaceContainerHigh)
                .cornerRadius(24)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.outlineVariant.opacity(0.5), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
            }

            // Delete Button
            Button(action: {
                showingDeleteConfirmation = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 16))
                    Text("Delete Log Entry")
                        .font(.body(15, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red)
                .cornerRadius(24)
            }
            .accessibilityIdentifier(LogDetailAccessibilityIdentifiers.deleteButton)
        }
    }

    // MARK: - Helper Views

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.primaryColor)

            Text(title.uppercased())
                .font(.label(11, weight: .bold))
                .foregroundColor(.primaryColor)
                .tracking(1.5)
        }
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            Rectangle()
                .fill(Color.outlineVariant.opacity(0.3))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Computed Properties

    private var hasGPSData: Bool {
        log.latitude != nil && log.longitude != nil
    }

    private func aqiLabel(_ aqi: Int) -> String {
        switch aqi {
        case 1: return "1 Good"
        case 2: return "2 Fair"
        case 3: return "3 Moderate"
        case 4: return "4 Poor"
        case 5: return "5 Very Poor"
        default: return "\(aqi)"
        }
    }

    // MARK: - Action Handlers

    private func shareLog() {
        // TODO: Implement share functionality
        print("Share log")
    }

    private func exportLog() {
        // TODO: Implement export functionality
        print("Export log")
    }

    private func deleteLog() {
        guard deleteConfirmationText.trimmingCharacters(in: .whitespaces).uppercased() == "DELETE" else { return }

        modelContext.delete(log)
        try? modelContext.save()
        dismiss()
    }

    // MARK: - Audio Playback

    private func playAudio(memo: AudioMemo) {
        if playingMemoId == memo.id {
            // Already playing this memo - stop it
            audioService.stopPlayback()
            playingMemoId = nil
        } else {
            // Stop any currently playing audio
            audioService.stopPlayback()

            // Play the selected memo
            audioService.playAudio(from: memo.audioURL)
            playingMemoId = memo.id
        }
    }
}

// MARK: - Supporting Views
// MetadataItem moved to HeroPhotoSection.swift for reusability

struct TelemetryCard: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.tertiary)

            Text(label.uppercased())
                .font(.label(10, weight: .bold))
                .foregroundColor(.onSurfaceVariant)
                .tracking(1.2)

            Text(value)
                .font(.display(18, weight: .black))
                .foregroundColor(.onSurface)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.surfaceContainerLow)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.outlineVariant.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Audio Memo Display Card (Read-Only)

struct AudioMemoDisplayCard: View {
    let memo: AudioMemo
    let index: Int
    let audioService: AudioRecorderService
    let isPlaying: Bool
    let onPlay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Memo #\(index) • \(memo.title)")
                    .font(.label(10, weight: .bold))
                    .foregroundColor(.onSurfaceVariant)
                    .tracking(1.2)

                Spacer()

                if memo.transcription != nil {
                    Text("TRANSCRIBED")
                        .font(.label(9, weight: .bold))
                        .foregroundColor(.onPrimaryContainer)
                        .tracking(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.primaryColor.opacity(0.15))
                        .cornerRadius(4)
                }
            }

            // Transcription (if available)
            if let transcription = memo.transcription {
                Text(transcription)
                    .font(.body(14))
                    .italic()
                    .foregroundColor(.onSurfaceVariant)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.5))
                    .cornerRadius(8)
            }

            // Audio Player Controls
            HStack(spacing: 12) {
                Button(action: onPlay) {
                    Circle()
                        .fill(Color.primaryColor)
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.onPrimary)
                        }
                }

                // Progress bar placeholder
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.surfaceContainerHighest)
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.primaryColor)
                            .frame(width: geometry.size.width * 0.0, height: 4) // No progress by default
                    }
                }
                .frame(height: 4)

                Text(formattedDuration(memo.duration))
                    .font(.label(11, weight: .regular))
                    .foregroundColor(.onSurfaceVariant)
                    .monospacedDigit()
            }
        }
        .padding(16)
        .background(Color.surfaceContainer)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.outlineVariant.opacity(0.3), lineWidth: 1)
        )
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// Helper extension for selective corner radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - View Modifiers

struct DeleteConfirmationAlert: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var confirmationText: String
    let onDelete: () -> Void

    func body(content: Content) -> some View {
        content
            .alert("Delete Log Entry", isPresented: $isPresented) {
                TextField("Type DELETE to confirm", text: $confirmationText)
                Button("Cancel", role: .cancel) {
                    confirmationText = ""
                }
                Button("Delete", role: .destructive) {
                    onDelete()
                }
                .disabled(confirmationText.trimmingCharacters(in: .whitespaces).uppercased() != "DELETE")
            } message: {
                Text("This will permanently delete this observation. This action cannot be undone.\n\nType DELETE to confirm.")
            }
    }
}

extension View {
    func deleteConfirmationAlert(
        isPresented: Binding<Bool>,
        confirmationText: Binding<String>,
        onDelete: @escaping () -> Void
    ) -> some View {
        modifier(DeleteConfirmationAlert(
            isPresented: isPresented,
            confirmationText: confirmationText,
            onDelete: onDelete
        ))
    }
}

// MARK: - Previews

#Preview("Complete Log with All Data") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Journal.self, Log.self, AudioMemo.self, configurations: config)

    let journal = Journal(name: "Olympic National Park")
    let log = Log(title: "Coastal Observation Log", notes: "Surface scan reveals unusual tectonic shifting near the shoreline. Bio-organic presence detected in the tide pools near sector 4. The structural integrity of the basalt stacks appears compromised by accelerated erosion.\n\nRecommend follow-up survey within 30 days to monitor progression of coastal changes.")
    log.latitude = 47.8021
    log.longitude = -123.6044
    log.altitude = 142.0
    log.weather = Weather(
        condition: "Clear",
        temperature: 64.1, // 18°C in Fahrenheit
        humidity: 92,
        windSpeed: 14.0, // km/h
        icon: "01d",
        aqi: 1,
        pm25: 5.2,
        pm10: 8.1
    )

    // Add multiple audio memos
    let memo1 = AudioMemo(
        title: "Soil Moisture",
        audioURL: URL(string: "file:///memo1.m4a")!,
        transcription: "Observed significant moisture levels in the soil at the base of the Hoh Rain Forest perimeter. Initial tests suggest increase in microbial activity.",
        duration: 42
    )
    memo1.log = log

    let memo2 = AudioMemo(
        title: "Ambient Acoustics",
        audioURL: URL(string: "file:///memo2.m4a")!,
        transcription: nil,
        duration: 75
    )
    memo2.log = log

    log.audioMemos = [memo1, memo2]

    journal.logs.append(log)
    container.mainContext.insert(journal)

    return NavigationStack {
        LogDetailView(log: log, journal: journal)
            .modelContainer(container)
    }
}

#Preview("Minimal Log - Notes Only") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Journal.self, Log.self, configurations: config)

    let journal = Journal(name: "Field Journal 2026")
    let log = Log(title: "Bird Activity Observation", notes: "Quick observation - noticed unusual bird activity in the western sector. Will follow up tomorrow with proper equipment.")

    journal.logs.append(log)
    container.mainContext.insert(journal)

    return NavigationStack {
        LogDetailView(log: log, journal: journal)
            .modelContainer(container)
    }
}

#Preview("With Single Voice Memo") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Journal.self, Log.self, AudioMemo.self, configurations: config)

    let journal = Journal(name: "Field Research")
    let log = Log(title: "Soil Analysis", notes: "Initial soil sample collection from northern sector. High clay content observed.")
    log.latitude = 47.8597
    log.longitude = -123.9346
    log.altitude = 182.0

    // Single audio memo with transcription
    let memo = AudioMemo(
        title: "Sample Collection Notes",
        audioURL: URL(string: "file:///sample-notes.m4a")!,
        transcription: "Collected three soil samples from depth of 15 centimeters. Samples show high moisture content and rich organic material. Will conduct pH testing in lab tomorrow.",
        duration: 58
    )
    memo.log = log
    log.audioMemos = [memo]

    journal.logs.append(log)
    container.mainContext.insert(journal)

    return NavigationStack {
        LogDetailView(log: log, journal: journal)
            .modelContainer(container)
    }
}

#Preview("With Photos & GPS") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Journal.self, Log.self, AudioMemo.self, configurations: config)

    let journal = Journal(name: "Coastal Survey")
    let log = Log(title: "Coastal Erosion Documentation", notes: "Documenting erosion patterns along the northern coastline. Three distinct formations showing advanced weathering.")
    log.latitude = 48.1234
    log.longitude = -124.5678
    log.altitude = 85.0
    log.mediaURLs = [
        URL(string: "https://picsum.photos/800/1000?1")!,
        URL(string: "https://picsum.photos/800/1000?2")!,
        URL(string: "https://picsum.photos/800/1000?3")!
    ]

    journal.logs.append(log)
    container.mainContext.insert(journal)

    return NavigationStack {
        LogDetailView(log: log, journal: journal)
            .modelContainer(container)
    }
}
