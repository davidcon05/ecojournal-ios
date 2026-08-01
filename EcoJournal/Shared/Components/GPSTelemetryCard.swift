//
//  GPSTelemetryCard.swift
//  EcoJournal
//
//  Created by David Contreras on 5/10/26.
//

import SwiftUI
import CoreLocation

struct GPSTelemetryCard: View {
    let location: CLLocation?
    let isLoading: Bool
    let error: String?
    var onRefresh: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 16) {
            // GPS Icon - red if error, mustard yellow if acquiring, primary color if success
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconBackgroundColor)
                    .frame(width: 48, height: 48)

                Image(systemName: "location.fill")
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
            }

            // Title and Subtitle
            VStack(alignment: .leading, spacing: 4) {
                Text("GPS TELEMETRY")
                    .font(.label(10, weight: .bold))
                    .foregroundColor(.tertiary)
                    .tracking(1.5)

                if let error = error {
                    Text(error)
                        .font(.body(14))
                        .foregroundColor(.error)
                        .lineLimit(2)
                } else if let location = location {
                    Text(formatCoordinates(location))
                        .font(.body(14))
                        .foregroundColor(.onSurface)
                        .lineLimit(2)
                } else {
                    Text("Acquiring signal...")
                        .font(.body(14))
                        .foregroundColor(.onSurfaceVariant)
                }
            }

            Spacer()

            // Refresh Button - only show if error or loading
            if let onRefresh = onRefresh, (hasError || isLoading) {
                Button(action: onRefresh) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.primaryColor)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primaryColor)
                    }
                }
                .disabled(isLoading)
                .opacity(isLoading ? 0.4 : 1.0)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.outlineVariant.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
    }

    private var hasError: Bool {
        error != nil
    }

    private var isAcquiring: Bool {
        location == nil && error == nil
    }

    private var iconBackgroundColor: Color {
        if hasError {
            return Color.red.opacity(0.1)
        } else if isAcquiring {
            return Color.yellow.mix(with: Color.orange, by: 0.5) // Darker mustard for background
        } else {
            return Color.primaryContainer
        }
    }

    private var iconColor: Color {
        if hasError {
            return .red
        } else {
            return .onPrimaryContainer // Same for both acquiring and success
        }
    }

    private func formatCoordinates(_ location: CLLocation) -> String {
        location.formattedDecimalDegrees
    }
}

#Preview("Success - With Location") {
    GPSTelemetryCard(
        location: CLLocation(latitude: 47.8013, longitude: -123.6044),
        isLoading: false,
        error: nil,
        onRefresh: {
            print("GPS refresh tapped")
        }
    )
    .padding()
}

#Preview("Acquiring Signal") {
    GPSTelemetryCard(
        location: nil,
        isLoading: true,
        error: nil,
        onRefresh: {
            print("GPS refresh tapped")
        }
    )
    .padding()
}

#Preview("Error - Red Icon with Refresh") {
    GPSTelemetryCard(
        location: nil,
        isLoading: false,
        error: "Location services disabled",
        onRefresh: {
            print("GPS refresh tapped")
        }
    )
    .padding()
}
