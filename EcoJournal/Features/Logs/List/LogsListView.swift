//
//  LogsListView.swift
//  EcoJournal
//
//  Created by David Contreras on 5/9/26.
//

import SwiftUI

struct LogsListView: View {
    let journal: Journal
    @State private var selectedLog: Log?
    @State private var searchText = ""
    @State private var sortOption: LogSortOption = .creationDate
    @State private var showingFilterSheet = false

    private var logThumbnailHeight: CGFloat {
        UIScreen.main.bounds.height * 0.19  // 19% of screen height
    }

    var body: some View {
        VStack(spacing: 0) {
            mainContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.background)
        .navigationDestination(item: $selectedLog) { log in
            LogDetailView(log: log, journal: journal)
        }
        .sheet(isPresented: $showingFilterSheet) {
            FilterSheet(selectedOption: $sortOption)
        }
    }

    // MARK: - Main Sections

    @ViewBuilder
    private var mainContent: some View {
        if journal.logs.isEmpty {
            emptyState
        } else {
            logsContent
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 60))
                .foregroundColor(.tertiaryColor)
                .accessibilityIdentifier(LogsListAccessibilityIdentifiers.emptyStateIcon)

            VStack(spacing: 8) {
                Text("No Logs Yet")
                    .font(.headline(20, weight: .bold))
                    .foregroundColor(.onSurface)
                    .accessibilityIdentifier(LogsListAccessibilityIdentifiers.emptyStateTitle)

                Text("Tap the New Log tab to create your first field observation")
                    .font(.body(15))
                    .foregroundColor(.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .accessibilityIdentifier(LogsListAccessibilityIdentifiers.emptyStateMessage)
            }

            Spacer()
        }
    }

    private var logsContent: some View {
        VStack(spacing: 0) {
            searchAndFilter
            scrollableContent
        }
    }

    private var searchAndFilter: some View {
        HStack(spacing: 12) {
            SearchBarWithDropdown(
                text: $searchText,
                placeholder: "Search logs...",
                suggestions: searchSuggestions,
                itemLabel: { $0.title },
                itemIcon: { _ in "doc.text.fill" },
                searchFieldIdentifier: LogsListAccessibilityIdentifiers.searchField,
                onSelectSuggestion: { log in
                    selectedLog = log
                }
            )

            FilterButton(
                isActive: isFilterActive,
                action: { showingFilterSheet.toggle() }
            )
            .accessibilityIdentifier(LogsListAccessibilityIdentifiers.filterButton)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .background(Color.background)
    }

    private var scrollableContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                logsList
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(headerTitle)
                        .font(.display(28, weight: .bold))
                        .foregroundColor(.onSurface)

                    Text(headerSubtitle)
                        .font(.body(15))
                        .foregroundColor(.onSurfaceVariant)
                }

                Spacer()
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    private var logsList: some View {
        LazyVStack(spacing: 24) {
            ForEach(Array(filteredAndSortedLogs.enumerated()), id: \.element.id) { index, log in
                if index < 3 {
                    FeaturedLogCardView(
                        log: log,
                        index: index,
                        onTapCard: { selectedLog = log }
                    )
                } else {
                    CompactLogCardView(log: log)
                        .onTapGesture {
                            selectedLog = log
                        }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    // MARK: - Computed Properties

    private var filteredAndSortedLogs: [Log] {
        var result = journal.logs

        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter { log in
                log.notes.localizedCaseInsensitiveContains(searchText) ||
                log.title.localizedCaseInsensitiveContains(searchText) ||
                log.audioMemos.contains { memo in
                    memo.title.localizedCaseInsensitiveContains(searchText) ||
                    (memo.transcription?.localizedCaseInsensitiveContains(searchText) ?? false)
                }
            }
        }

        // Apply sort
        switch sortOption {
        case .creationDate:
            result = result.sorted { $0.timestamp > $1.timestamp }
        case .aToZ:
            result = result.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .zToA:
            result = result.sorted { $0.title.localizedCompare($1.title) == .orderedDescending }
        }

        return result
    }

    private var isFilterActive: Bool {
        sortOption != .creationDate
    }

    private var headerTitle: String {
        searchText.isEmpty ? "Recent Logs" : "Search Results"
    }

    private var headerSubtitle: String {
        if searchText.isEmpty {
            return "Synchronized field entries and observations"
        } else {
            let count = filteredAndSortedLogs.count
            return "\(count) result\(count == 1 ? "" : "s") found"
        }
    }

    private var searchSuggestions: [Log] {
        guard !searchText.isEmpty else { return [] }

        // Filter logs that match the search text and sort by best match
        return journal.logs
            .filter { log in
                log.title.localizedCaseInsensitiveContains(searchText) ||
                log.notes.localizedCaseInsensitiveContains(searchText) ||
                log.audioMemos.contains { memo in
                    memo.title.localizedCaseInsensitiveContains(searchText) ||
                    (memo.transcription?.localizedCaseInsensitiveContains(searchText) ?? false)
                }
            }
            .sorted { lhs, rhs in
                let lhsTitle = lhs.title.lowercased()
                let rhsTitle = rhs.title.lowercased()
                let search = searchText.lowercased()

                // Prioritize title prefix matches
                let lhsStartsWith = lhsTitle.hasPrefix(search)
                let rhsStartsWith = rhsTitle.hasPrefix(search)

                if lhsStartsWith != rhsStartsWith {
                    return lhsStartsWith
                }

                // Then sort by most recent
                return lhs.timestamp > rhs.timestamp
            }
    }
}

// MARK: - Featured Log Card (First 3)

struct FeaturedLogCardView: View {
    let log: Log
    let index: Int
    let onTapCard: () -> Void

    @State private var isExpanded = false

    private var logThumbnailHeight: CGFloat {
        UIScreen.main.bounds.height * 0.19  // 19% of screen height
    }

    var body: some View {
        VStack(spacing: 0) {
                // Image section with circular chevron button
                ZStack(alignment: .bottomTrailing) {
                    // Priority: Use actual log photos, then fallback to alternating color gradients
                    Group {
                        if !log.mediaURLs.isEmpty, let firstPhotoURL = log.mediaURLs.first {
                            // Use actual photo from log
                            AsyncImage(url: firstPhotoURL) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: logThumbnailHeight)
                                        .clipped()
                                case .failure(_), .empty:
                                    // Fallback to alternating gradient if photo fails to load
                                    alternatingGradient
                                        .frame(height: logThumbnailHeight)
                                @unknown default:
                                    alternatingGradient
                                        .frame(height: logThumbnailHeight)
                                }
                            }
                        } else {
                            // No photos: use alternating gradient based on index
                            alternatingGradient
                                .frame(height: logThumbnailHeight)
                        }
                    }
                    .contentShape(Rectangle())

                    // Weather icon badge (top left)
                    HStack(spacing: 6) {
                        Image(systemName: weatherIconName(for: log.weather?.icon ?? "01d"))
                            .font(.system(size: 14))
                            .foregroundColor(.white)

                        if let weather = log.weather {
                            Text(weather.condition)
                                .font(.label(11, weight: .bold))
                                .foregroundColor(.white)
                                .tracking(0.5)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(12)
                    .allowsHitTesting(false)

                    // TODO: Re-implement chevron dropdown functionality
                    // Circular chevron button (bottom right, overlapping border)
                    // Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                    //     ZStack {
                    //         Circle()
                    //             .fill(Color.white)
                    //             .frame(width: 36, height: 36)
                    //             .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    //
                    //         Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    //             .font(.system(size: 14, weight: .semibold))
                    //             .foregroundColor(.primaryColor)
                    //     }
                    // }
                    // .buttonStyle(.plain)
                    // .accessibilityIdentifier(LogsListAccessibilityIdentifiers.featuredCardChevron(index))
                    // .offset(x: -12, y: 18) // Overlap border between image and content
                }

                // Content section
                VStack(alignment: .leading, spacing: 12) {
                    if isExpanded {
                        // Expanded: Show title, date, full notes, and weather data
                        VStack(alignment: .leading, spacing: 8) {
                            // Title
                            Text(log.title)
                                .font(.body(16, weight: .bold))
                                .foregroundColor(.onSurface)
                                .lineLimit(2)

                            // Date
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 12))
                                Text(log.timestamp, format: .dateTime.month().day().year().hour().minute())
                                    .font(.label(12, weight: .medium))
                            }
                            .foregroundColor(.onSurfaceVariant)

                            // Full notes
                            Text(log.notes)
                                .font(.body(14))
                                .foregroundColor(.onSurfaceVariant)
                                .lineSpacing(4)
                                .accessibilityIdentifier(LogsListAccessibilityIdentifiers.featuredCardExpandedNotes(index))

                            Divider()
                                .padding(.vertical, 4)

                            // Weather data
                            VStack(alignment: .leading, spacing: 8) {
                                MetadataRow(
                                    icon: "location.fill",
                                    label: "Location",
                                    value: {
                                        if let lat = log.latitude, let lon = log.longitude {
                                            return String(format: "%.4f°, %.4f°", lat, lon)
                                        }
                                        return "--"
                                    }()
                                )

                                MetadataRow(
                                    icon: "thermometer.medium",
                                    label: "Temperature",
                                    value: log.weather.map { String(format: "%.0f°F", celsiusToFahrenheit($0.temperature)) } ?? "--"
                                )

                                MetadataRow(
                                    icon: "humidity.fill",
                                    label: "Humidity",
                                    value: log.weather.map { "\($0.humidity)%" } ?? "--"
                                )

                                MetadataRow(
                                    icon: "wind",
                                    label: "Air Quality",
                                    value: log.weather?.aqiDescription ?? "--"
                                )

                                MetadataRow(
                                    icon: "mountain.2.fill",
                                    label: "Altitude",
                                    value: log.altitude.map { String(format: "%.0fm", $0) } ?? "--"
                                )
                            }
                            .accessibilityIdentifier(LogsListAccessibilityIdentifiers.featuredCardWeatherData(index))
                        }
                    } else {
                        // Collapsed: Just show title and date
                        VStack(alignment: .leading, spacing: 8) {
                            Text(log.title)
                                .font(.body(16, weight: .bold))
                                .foregroundColor(.onSurface)
                                .lineLimit(2)

                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 12))
                                Text(log.timestamp, format: .dateTime.month().day().year().hour().minute())
                                    .font(.label(12, weight: .medium))
                            }
                            .foregroundColor(.onSurfaceVariant)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .accessibilityIdentifier(LogsListAccessibilityIdentifiers.featuredCardContent(index))
                .onTapGesture {
                    onTapCard()
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
            .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(LogsListAccessibilityIdentifiers.featuredCard(index))
    }

    private var alternatingGradient: LinearGradient {
        // Alternating colors to avoid back-to-back same colors
        let gradients: [(Color, Color)] = [
            (Color.blue.opacity(0.6), Color.blue.opacity(0.4)),
            (Color.green.opacity(0.6), Color.green.opacity(0.4)),
            (Color.orange.opacity(0.6), Color.orange.opacity(0.4)),
            (Color.purple.opacity(0.6), Color.purple.opacity(0.4)),
            (Color.teal.opacity(0.6), Color.teal.opacity(0.4))
        ]

        let gradientIndex = index % gradients.count
        let selectedGradient = gradients[gradientIndex]

        return LinearGradient(
            colors: [selectedGradient.0, selectedGradient.1],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func celsiusToFahrenheit(_ celsius: Double) -> Double {
        return (celsius * 9/5) + 32
    }

    private func weatherIconName(for iconCode: String) -> String {
        switch iconCode {
        case "01d": return "sun.max.fill"
        case "01n": return "moon.fill"
        case "02d", "02n": return "cloud.sun.fill"
        case "03d", "03n": return "cloud.fill"
        case "04d", "04n": return "smoke.fill"
        case "09d", "09n": return "cloud.rain.fill"
        case "10d", "10n": return "cloud.sun.rain.fill"
        case "11d", "11n": return "cloud.bolt.fill"
        case "13d", "13n": return "snow"
        case "50d", "50n": return "cloud.fog.fill"
        default: return "cloud.sun.fill"
        }
    }
}

// MARK: - Compact Log Card (Remaining)

struct CompactLogCardView: View {
    let log: Log

    var body: some View {
        HStack(spacing: 12) {
                // Weather icon
                if let weather = log.weather {
                    ZStack {
                        Circle()
                            .fill(Color.primaryContainer.opacity(0.2))
                            .frame(width: 44, height: 44)

                        Image(systemName: weatherIconName(for: weather.icon))
                            .font(.system(size: 20))
                            .foregroundColor(.primaryColor)
                    }
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(log.notes.components(separatedBy: ".").first ?? log.notes)
                        .font(.body(15, weight: .semibold))
                        .foregroundColor(.onSurface)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                        Text(log.timestamp, format: .dateTime.month().day().hour().minute())
                            .font(.label(11))
                    }
                    .foregroundColor(.onSurfaceVariant)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.outline)
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
            .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        }
    }

    private func weatherIconName(for iconCode: String) -> String {
        switch iconCode {
        case "01d": return "sun.max.fill"
        case "01n": return "moon.fill"
        case "02d", "02n": return "cloud.sun.fill"
        case "03d", "03n": return "cloud.fill"
        case "04d", "04n": return "smoke.fill"
        case "09d", "09n": return "cloud.rain.fill"
        case "10d", "10n": return "cloud.sun.rain.fill"
        case "11d", "11n": return "cloud.bolt.fill"
        case "13d", "13n": return "snow"
        case "50d", "50n": return "cloud.fog.fill"
        default: return "cloud.sun.fill"
        }
    }


// MARK: - Metadata Row

struct MetadataRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.primaryColor)
                .frame(width: 20)

            Text(label)
                .font(.label(12, weight: .medium))
                .foregroundColor(.onSurfaceVariant)

            Spacer()

            Text(value)
                .font(.label(12, weight: .semibold))
                .foregroundColor(.onSurface)
        }
    }
}

#Preview("Empty State") {
    LogsListView(journal: Journal(name: "Test Journal"))
}

#Preview("With Logs") {
    let journal = Journal(name: "Olympic National Park")

    let log1 = Log(title: "Hoh Rain Forest Moss Samples", notes: "Found vibrant moss samples in Hoh Rain Forest. Massive Sitka spruce and western red cedar create a dense canopy.")
    log1.latitude = 47.8597
    log1.longitude = -123.9346
    log1.altitude = 182
    log1.weather = Weather(
        condition: "Rain",
        temperature: 12.5,
        humidity: 95,
        windSpeed: 2.1,
        icon: "10d",
        aqi: 1,
        pm25: 8.5,
        pm10: 12.3
    )
    journal.logs.append(log1)

    let log2 = Log(title: "Hurricane Ridge Wildflowers", notes: "Spectacular alpine wildflower meadows at Hurricane Ridge. Clear views of Mount Olympus.")
    log2.latitude = 47.9697
    log2.longitude = -123.4985
    log2.altitude = 1605
    log2.weather = Weather(
        condition: "Clear",
        temperature: 15.2,
        humidity: 45,
        windSpeed: 8.5,
        icon: "01d",
        aqi: 1,
        pm25: 5.2,
        pm10: 8.1
    )
    journal.logs.append(log2)

    let log3 = Log(title: "Rialto Beach Tide Pools", notes: "Exploring tide pools at Rialto Beach. Sea stars, anemones, and kelp forests visible during low tide.")
    log3.latitude = 47.9212
    log3.longitude = -124.6378
    log3.altitude = 3
    log3.weather = Weather(
        condition: "Clouds",
        temperature: 13.8,
        humidity: 78,
        windSpeed: 5.2,
        icon: "04d",
        aqi: 2,
        pm25: 15.8,
        pm10: 22.4
    )
    journal.logs.append(log3)

    return LogsListView(journal: journal)
}
