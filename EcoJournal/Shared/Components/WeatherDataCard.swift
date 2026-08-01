//
//  WeatherDataCard.swift
//  EcoJournal
//
//  Created by David Contreras on 5/10/26.
//

import SwiftUI
import CoreLocation

struct WeatherDataCard: View {
    let weather: Weather?
    let location: CLLocation?
    let isLoading: Bool
    let error: String?
    var onRefresh: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            // Weather Icon Section (1/3 width)
            ZStack {
                // Gradient background based on weather condition
                LinearGradient(
                    colors: weatherGradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Weather Icon or Spinner
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                } else if let weather = weather {
                    weatherIcon(for: weather.icon)
                        .font(.system(size: 48))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "cloud.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(width: UIScreen.main.bounds.width * 0.25)

            // Data Section (3/4 width)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("ENVIRONMENT DATA")
                        .font(.label(10, weight: .bold))
                        .foregroundColor(.tertiary)
                        .tracking(1.5)

                    Spacer()

                    if let onRefresh = onRefresh {
                        Button(action: onRefresh) {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .tint(.primaryColor)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primaryColor)
                            }
                        }
                        .disabled(location == nil || isLoading)
                        .opacity((location == nil || isLoading) ? 0.4 : 1.0)
                    }
                }

                if let error = error {
                    Text(error)
                        .font(.body(12))
                        .foregroundColor(.error)
                        .lineLimit(2)
                } else {
                    // Always show the structure with data or placeholders
                    HStack(spacing: 16) {
                        // Temperature
                        DataPoint(
                            label: "TEMP",
                            value: weather.map { String(format: "%.0f°F", celsiusToFahrenheit($0.temperature)) } ?? "--"
                        )

                        // Humidity
                        DataPoint(
                            label: "HUMIDITY",
                            value: weather.map { "\($0.humidity)%" } ?? "--"
                        )

                        // Loading spinner if acquiring
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.primaryColor)
                        }
                    }

                    HStack(spacing: 16) {
                        // Altitude
                        DataPoint(
                            label: "ALTITUDE",
                            value: location.map { String(format: "%.0fm", $0.altitude) } ?? "--"
                        )

                        // Wind Speed
                        DataPoint(
                            label: "WIND",
                            value: weather.map { String(format: "%.1f mph", $0.windSpeedMPH) } ?? "--"
                        )
                    }

                    // Air Quality (if available)
                    if let weather = weather, let aqi = weather.aqi, let aqiDesc = weather.aqiDescription {
                        HStack(spacing: 16) {
                            DataPoint(
                                label: "AIR QUALITY",
                                value: aqiDesc,
                                color: aqiColor(for: aqi)
                            )

                            if let pm25 = weather.pm25 {
                                DataPoint(
                                    label: "PM2.5",
                                    value: String(format: "%.1f μg/m³", pm25)
                                )
                            }
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.surfaceContainer.opacity(0.5))
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.outlineVariant.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
    }

    private func celsiusToFahrenheit(_ celsius: Double) -> Double {
        return (celsius * 9/5) + 32
    }

    private var weatherGradient: [Color] {
        guard let weather = weather else {
            return [Color.gray.opacity(0.6), Color.gray.opacity(0.4)]
        }

        // Map weather conditions to color gradients
        switch weather.condition.lowercased() {
        case _ where weather.condition.contains("clear"):
            return [Color.blue.opacity(0.7), Color.cyan.opacity(0.5)]
        case _ where weather.condition.contains("cloud"):
            return [Color.gray.opacity(0.6), Color.gray.opacity(0.4)]
        case _ where weather.condition.contains("rain"):
            return [Color.blue.opacity(0.8), Color.indigo.opacity(0.6)]
        case _ where weather.condition.contains("snow"):
            return [Color.cyan.opacity(0.7), Color.white.opacity(0.6)]
        default:
            return [Color.primaryColor.opacity(0.6), Color.secondaryColor.opacity(0.4)]
        }
    }

    private func weatherIcon(for iconCode: String) -> Image {
        // Map OpenWeatherMap icon codes to SF Symbols
        switch iconCode {
        case "01d": return Image(systemName: "sun.max.fill")
        case "01n": return Image(systemName: "moon.fill")
        case "02d", "02n": return Image(systemName: "cloud.sun.fill")
        case "03d", "03n": return Image(systemName: "cloud.fill")
        case "04d", "04n": return Image(systemName: "smoke.fill")
        case "09d", "09n": return Image(systemName: "cloud.rain.fill")
        case "10d", "10n": return Image(systemName: "cloud.sun.rain.fill")
        case "11d", "11n": return Image(systemName: "cloud.bolt.fill")
        case "13d", "13n": return Image(systemName: "snow")
        case "50d", "50n": return Image(systemName: "cloud.fog.fill")
        default: return Image(systemName: "cloud.sun.fill")
        }
    }

    private func aqiColor(for aqi: Int) -> Color {
        switch aqi {
        case 1: return Color.green // Good
        case 2: return Color.yellow // Fair
        case 3: return Color.orange // Moderate
        case 4: return Color.red // Poor
        case 5: return Color.purple // Very Poor
        default: return Color.gray
        }
    }
}

struct DataPoint: View {
    let label: String
    let value: String
    var color: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.label(10, weight: .bold))
                .foregroundColor(.outline)
                .tracking(1)

            Text(value)
                .font(.display(20, weight: .black))
                .foregroundColor(color ?? .onSurface)
        }
    }
}

#Preview("With Weather Data") {
    WeatherDataCard(
        weather: Weather(
            condition: "Clear",
            temperature: 18.5,
            humidity: 82,
            windSpeed: 3.2,
            icon: "01d",
            aqi: 1,
            pm25: 8.5,
            pm10: 12.3
        ),
        location: CLLocation(latitude: 47.8013, longitude: -123.6044),
        isLoading: false,
        error: nil,
        onRefresh: {
            print("Weather refresh tapped")
        }
    )
    .padding()
}

#Preview("Loading") {
    WeatherDataCard(
        weather: nil,
        location: nil,
        isLoading: true,
        error: nil,
        onRefresh: {
            print("Weather refresh tapped")
        }
    )
    .padding()
}

#Preview("Error State") {
    WeatherDataCard(
        weather: nil,
        location: CLLocation(latitude: 47.8013, longitude: -123.6044),
        isLoading: false,
        error: "Failed to fetch weather data - service unavailable",
        onRefresh: {
            print("Weather refresh tapped")
        }
    )
    .padding()
}

#Preview("Waiting for Location") {
    WeatherDataCard(
        weather: nil,
        location: nil,
        isLoading: false,
        error: nil,
        onRefresh: {
            print("Weather refresh tapped")
        }
    )
    .padding()
}

#Preview("Refreshing with Data") {
    WeatherDataCard(
        weather: Weather(
            condition: "Cloudy",
            temperature: 15.0,
            humidity: 75,
            windSpeed: 4.5,
            icon: "04d",
            aqi: 2,
            pm25: 15.2,
            pm10: 22.1
        ),
        location: CLLocation(latitude: 47.8013, longitude: -123.6044),
        isLoading: true,
        error: nil,
        onRefresh: {
            print("Weather refresh tapped")
        }
    )
    .padding()
}

#Preview("No Refresh Button") {
    WeatherDataCard(
        weather: Weather(
            condition: "Rain",
            temperature: 12.0,
            humidity: 90,
            windSpeed: 6.2,
            icon: "09d",
            aqi: 1,
            pm25: 5.5,
            pm10: 8.3
        ),
        location: CLLocation(latitude: 47.8013, longitude: -123.6044),
        isLoading: false,
        error: nil,
        onRefresh: nil
    )
    .padding()
}
