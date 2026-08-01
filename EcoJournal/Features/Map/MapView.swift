//
//  MapView.swift
//  EcoJournal
//
//  Created by David Contreras on 5/9/26.
//

import SwiftUI
import MapKit

struct MapView: View {
    let journal: Journal

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedLog: Log?
    @State private var isMetricsExpanded: Bool = false

    /// Pin selection, metrics, and framing live here so they can be tested
    /// without rendering a map. See MapViewModel.
    private var viewModel: MapViewModel { MapViewModel(journal: journal) }

    // Dynamic height for annotation photo preview
    private var annotationPhotoHeight: CGFloat {
        UIScreen.main.bounds.height * 0.12  // 12% of screen height
    }

    private var logsWithGPS: [Log] { viewModel.logsWithGPS }
    private var averageElevation: String { viewModel.averageElevation }
    private var averageHumidity: String { viewModel.averageHumidity }
    private var averageTemp: String { viewModel.averageTemp }

    var body: some View {
        ZStack {
            mainContent
            overlayElements
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        if logsWithGPS.isEmpty {
            emptyStateView
        } else {
            mapWithPins
        }
    }

    private var mapWithPins: some View {
        Map(position: $position) {
            ForEach(logsWithGPS) { log in
                if let lat = log.latitude, let lon = log.longitude {
                    Annotation("", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)) {
                        pinView(for: log, isSelected: selectedLog?.id == log.id)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    if selectedLog?.id == log.id {
                                        selectedLog = nil
                                    } else {
                                        selectedLog = log
                                    }
                                }
                            }
                    }
                }
            }
        }
        .mapStyle(.hybrid)
        .accessibilityIdentifier(MapAccessibilityIdentifiers.mapView)
        .onAppear {
            if !logsWithGPS.isEmpty {
                centerMapOnLogs()
            }
        }
    }

    @ViewBuilder
    private var overlayElements: some View {
        if !logsWithGPS.isEmpty {
            metricsPanel
            locationButton
            calloutPopup
        }
    }

    private var metricsPanel: some View {
        VStack {
            HStack {
                Spacer()
                liveMetricsPanel
                    .frame(maxWidth: UIScreen.main.bounds.width / 3)
            }
            Spacer()
        }
        .padding(16)
    }

    private var locationButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                centerLocationButton
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private var calloutPopup: some View {
        if let selectedLog = selectedLog {
            VStack(spacing: 0) {
                Spacer()

                Rectangle()
                    .fill(Color.orange.opacity(0.4))
                    .frame(width: 2, height: 60)

                logCalloutCard(for: selectedLog)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Live Metrics Panel

    private var liveMetricsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header (always visible, tappable)
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.primaryColor)
                    .frame(width: 6, height: 6)
                    .shadow(color: .primaryColor.opacity(0.5), radius: 4)

                Text("LIVE METRICS")
                    .font(.label(10, weight: .bold))
                    .foregroundColor(.tertiary)
                    .tracking(1.5)

                Spacer()

                Image(systemName: isMetricsExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.tertiary)
            }

            // Metrics (conditionally shown)
            if isMetricsExpanded {
                VStack(spacing: 8) {
                    metricRow(label: "Elevation", value: averageElevation)
                    metricRow(label: "Humidity", value: averageHumidity)
                    metricRow(label: "Temp", value: averageTemp)
                }
            }
        }
        .padding(12)
        .background(
            Color.white.opacity(0.7)
                .background(.ultraThinMaterial)
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.outlineVariant.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        .accessibilityIdentifier(MapAccessibilityIdentifiers.metricsPanel)
        .onTapGesture {
            withAnimation(.spring(response: 0.3)) {
                isMetricsExpanded.toggle()
            }
        }
    }

    private func metricRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.body(12, weight: .semibold))
                .foregroundColor(.onSurfaceVariant)

            Spacer()

            Text(value)
                .font(.body(12, weight: .bold))
                .foregroundColor(.onSurface)
        }
    }

    // MARK: - Pin View

    private func pinView(for log: Log, isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.orange : pinColor(for: log))
                .frame(width: isSelected ? 40 : 32, height: isSelected ? 40 : 32)
                .shadow(color: .black.opacity(0.3), radius: isSelected ? 6 : 3, x: 0, y: 2)

            if isSelected {
                Circle()
                    .stroke(Color.orange.opacity(0.3), lineWidth: 4)
                    .frame(width: 48, height: 48)
            }

            Image(systemName: pinIcon(for: log))
                .font(.system(size: isSelected ? 18 : 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .animation(.spring(response: 0.3), value: isSelected)
    }

    private func pinColor(for log: Log) -> Color {
        viewModel.pinStyle(for: log).color
    }

    private func pinIcon(for log: Log) -> String {
        viewModel.pinStyle(for: log).iconName
    }

    // MARK: - Custom Callout Card

    private func logCalloutCard(for log: Log) -> some View {
        VStack(spacing: 0) {
            // Image Preview (reduced height to 70)
            ZStack(alignment: .topTrailing) {
                // Show actual image from mediaURLs or placeholder
                if !log.mediaURLs.isEmpty, let firstMediaURL = log.mediaURLs.first {
                    AsyncImage(url: firstMediaURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: annotationPhotoHeight)
                                .clipped()
                        case .failure(_), .empty:
                            // Fallback to placeholder if photo fails to load
                            Rectangle()
                                .fill(Color.surfaceContainerHigh)
                                .frame(height: annotationPhotoHeight)
                                .overlay(
                                    Image(systemName: "camera")
                                        .font(.system(size: 28))
                                        .foregroundColor(.onSurfaceVariant.opacity(0.3))
                                )
                        @unknown default:
                            Rectangle()
                                .fill(Color.surfaceContainerHigh)
                                .frame(height: annotationPhotoHeight)
                                .overlay(
                                    Image(systemName: "camera")
                                        .font(.system(size: 28))
                                        .foregroundColor(.onSurfaceVariant.opacity(0.3))
                                )
                        }
                    }
                } else {
                    // No photos: show placeholder
                    Rectangle()
                        .fill(Color.surfaceContainerHigh)
                        .frame(height: annotationPhotoHeight)
                        .overlay(
                            Image(systemName: "camera")
                                .font(.system(size: 28))
                                .foregroundColor(.onSurfaceVariant.opacity(0.3))
                        )
                }

                // Close Button (top-right of image)
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedLog = nil
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.onSurface)
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.95))
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                }
                .accessibilityIdentifier(MapAccessibilityIdentifiers.calloutCloseButton)
                .padding(8)
            }

            // Card Content (increased height with more spacing)
            VStack(alignment: .leading, spacing: 10) {
                // Title
                Text(log.title)
                    .font(.headline(14, weight: .bold))
                    .foregroundColor(.onSurface)
                    .lineLimit(1)

                // Date and Details Button on same line
                HStack {
                    Text(log.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.body(11))
                        .foregroundColor(.onSurfaceVariant)

                    Spacer()

                    NavigationLink(destination: LogDetailView(log: log, journal: journal)) {
                        Text("Details")
                            .font(.body(12, weight: .semibold))
                            .foregroundColor(.onPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.primaryColor)
                            .cornerRadius(6)
                    }
                    .accessibilityIdentifier(MapAccessibilityIdentifiers.calloutDetailsButton)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.outlineVariant.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 4)
        .accessibilityIdentifier(MapAccessibilityIdentifiers.calloutCard)
    }

    // MARK: - Center Location Button

    private var centerLocationButton: some View {
        Button {
            centerMapOnLogs()
        } label: {
            Image(systemName: "location.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(Color.orange)
                .cornerRadius(24)
                .overlay(
                    Circle()
                        .stroke(Color.orange.opacity(0.3), lineWidth: 2)
                )
                .shadow(color: Color.orange.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .accessibilityIdentifier(MapAccessibilityIdentifiers.centerLocationButton)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "map")
                    .font(.system(size: 60))
                    .foregroundColor(.tertiaryColor)
                    .accessibilityIdentifier(MapAccessibilityIdentifiers.emptyStateIcon)

                VStack(spacing: 8) {
                    Text("No GPS Data")
                        .font(.headline(20, weight: .bold))
                        .foregroundColor(.onSurface)
                        .accessibilityIdentifier(MapAccessibilityIdentifiers.emptyStateTitle)

                    Text("Logs with GPS coordinates will appear here")
                        .font(.body(15))
                        .foregroundColor(.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .accessibilityIdentifier(MapAccessibilityIdentifiers.emptyStateMessage)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfaceBackground)
    }

    // MARK: - Map Helpers

    private func centerMapOnLogs() {
        guard let region = viewModel.regionCoveringAllLogs else { return }

        withAnimation {
            position = .region(region)
        }
    }
}

// MARK: - Previews

#Preview("With GPS Logs") {
    let journal = Journal(name: "Olympic National Park")

    // Add logs with GPS coordinates
    let log1 = Log(title: "Rare Moss Discovery", notes: "Found rare moss species near creek")
    log1.latitude = 47.8597
    log1.longitude = -123.9346
    log1.altitude = 182.0
    log1.weather = Weather(condition: "Clear", temperature: 18.5, humidity: 62, windSpeed: 3.2, icon: "01d", aqi: 1, pm25: 8.5, pm10: 12.3)
    log1.mediaURLs = [] // No photos in preview - will show alternating gradient

    let log2 = Log(title: "Water Quality Sample", notes: "Water quality sample - pH 7.2")
    log2.latitude = 47.8612
    log2.longitude = -123.9361
    log2.altitude = 156.0
    log2.mediaURLs = [] // No photos in preview - will show alternating gradient

    let log3 = Log(title: "Eagle Nest Observation", notes: "Eagle nest spotted in old growth Douglas fir")
    log3.latitude = 47.8585
    log3.longitude = -123.9320
    log3.altitude = 210.0
    log3.mediaURLs = [] // No photos in preview - will show alternating gradient

    let log4 = Log(title: "Trail Erosion Assessment", notes: "Trail erosion assessment")
    log4.latitude = 47.8620
    log4.longitude = -123.9380
    log4.altitude = 145.0
    // Audio memo (for purple pin color) - actual AudioMemo objects not needed for map preview
    let audioMemo = AudioMemo(title: "Trail Notes", audioURL: URL(string: "file:///memo.m4a")!, duration: 45)
    audioMemo.log = log4
    log4.audioMemos = [audioMemo]

    let log5 = Log(title: "Invasive Species", notes: "Invasive plant species")
    log5.latitude = 47.8575
    log5.longitude = -123.9355
    log5.altitude = 175.0

    journal.logs.append(contentsOf: [log1, log2, log3, log4, log5])

    return NavigationStack {
        MapView(journal: journal)
            .navigationDestination(for: Log.self) { log in
                Text("Edit Log View for: \(log.notes)")
            }
    }
}

#Preview("Empty State - No GPS") {
    let journal = Journal(name: "Test Journal")

    // Add logs WITHOUT GPS coordinates
    journal.logs.append(Log(title: "Indoor Observation", notes: "Indoor observation - no GPS"))
    journal.logs.append(Log(title: "Lab Notes", notes: "Lab notes"))

    return NavigationStack {
        MapView(journal: journal)
    }
}

#Preview("Single Log") {
    let journal = Journal(name: "Single Point")

    let log = Log(title: "Single Observation", notes: "Single observation point")
    log.latitude = 47.8597
    log.longitude = -123.9346
    log.altitude = 182.0

    journal.logs.append(log)

    return NavigationStack {
        MapView(journal: journal)
    }
}

#Preview("Callout Visible") {
    let journal = Journal(name: "Olympic National Park")

    let log = Log(title: "Rare Moss Discovery", notes: "Found rare moss species near creek\nSample collected for lab analysis")
    log.latitude = 47.8597
    log.longitude = -123.9346
    log.altitude = 182.0
    log.weather = Weather(condition: "Clear", temperature: 18.5, humidity: 62, windSpeed: 3.2, icon: "01d", aqi: 1, pm25: 8.5, pm10: 12.3)
    log.mediaURLs = []

    journal.logs.append(log)

    return NavigationStack {
        MapViewWithCallout(journal: journal, selectedLog: log)
    }
}

// Helper view for preview with callout
private struct MapViewWithCallout: View {
    let journal: Journal
    @State var selectedLog: Log?

    private var annotationPhotoHeight: CGFloat {
        UIScreen.main.bounds.height * 0.12  // 12% of screen height
    }

    init(journal: Journal, selectedLog: Log) {
        self.journal = journal
        _selectedLog = State(initialValue: selectedLog)
    }

    var body: some View {
        let logsWithGPS = journal.logs.filter { $0.latitude != nil && $0.longitude != nil }

        ZStack {
            Map {
                ForEach(logsWithGPS) { log in
                    if let lat = log.latitude, let lon = log.longitude {
                        Annotation("", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 40, height: 40)
                        }
                    }
                }
            }
            .mapStyle(.hybrid)

            // Custom Callout Popup
            if let selectedLog = selectedLog {
                VStack(spacing: 0) {
                    Spacer()

                    // Connection line from pin to callout
                    Rectangle()
                        .fill(Color.orange.opacity(0.4))
                        .frame(width: 2, height: 60)

                    logCalloutCard(for: selectedLog, journal: journal)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 40)
                }
            }
        }
    }

    private func logCalloutCard(for log: Log, journal: Journal) -> some View {
        VStack(spacing: 0) {
            // Image Preview (reduced height to 70)
            ZStack(alignment: .topTrailing) {
                // Show actual image from mediaURLs or placeholder
                if !log.mediaURLs.isEmpty, let firstMediaURL = log.mediaURLs.first {
                    AsyncImage(url: firstMediaURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: annotationPhotoHeight)
                                .clipped()
                        case .failure(_), .empty:
                            // Fallback to placeholder if photo fails to load
                            Rectangle()
                                .fill(Color.surfaceContainerHigh)
                                .frame(height: annotationPhotoHeight)
                                .overlay(
                                    Image(systemName: "camera")
                                        .font(.system(size: 28))
                                        .foregroundColor(.onSurfaceVariant.opacity(0.3))
                                )
                        @unknown default:
                            Rectangle()
                                .fill(Color.surfaceContainerHigh)
                                .frame(height: annotationPhotoHeight)
                                .overlay(
                                    Image(systemName: "camera")
                                        .font(.system(size: 28))
                                        .foregroundColor(.onSurfaceVariant.opacity(0.3))
                                )
                        }
                    }
                } else {
                    // No photos: show placeholder
                    Rectangle()
                        .fill(Color.surfaceContainerHigh)
                        .frame(height: annotationPhotoHeight)
                        .overlay(
                            Image(systemName: "camera")
                                .font(.system(size: 28))
                                .foregroundColor(.onSurfaceVariant.opacity(0.3))
                        )
                }

                // Close Button (top-right of image)
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedLog = nil
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.onSurface)
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.95))
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                }
                .padding(8)
            }

            // Card Content (increased height with more spacing)
            VStack(alignment: .leading, spacing: 10) {
                // Title
                Text(log.title)
                    .font(.headline(14, weight: .bold))
                    .foregroundColor(.onSurface)
                    .lineLimit(1)

                // Date and Details Button on same line
                HStack {
                    Text(log.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.body(11))
                        .foregroundColor(.onSurfaceVariant)

                    Spacer()

                    NavigationLink(destination: LogDetailView(log: log, journal: journal)) {
                        Text("Details")
                            .font(.body(12, weight: .semibold))
                            .foregroundColor(.onPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.primaryColor)
                            .cornerRadius(6)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.outlineVariant.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 4)
    }
}
