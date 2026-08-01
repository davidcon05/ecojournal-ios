//
//  EcoJournalApp.swift
//  EcoJournal
//
//  Created by David Contreras on 5/5/26.
//

import SwiftUI
import SwiftData

@main
struct EcoJournalApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Journal.self,
            Log.self,
            AudioMemo.self,
        ])
        // Using persistent storage for field testing and map development
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])

            // Clear state when running UI tests (equivalent to Maestro's clearState: true)
            if ProcessInfo.processInfo.arguments.contains("--uitesting") {
                let context = ModelContext(container)
                do {
                    // Delete all journals (cascade will delete logs and audio memos)
                    try context.delete(model: Journal.self)
                    try context.save()

                    // Seed fixture data for tests where existing data is a precondition
                    // rather than the behavior under test (see UITestSeedData.swift)
                    if let seedJSON = ProcessInfo.processInfo.environment["UITEST_SEED_DATA"],
                       let seedData = seedJSON.data(using: .utf8) {
                        // Real files on disk, so seeded photos and memos can
                        // actually be loaded and played rather than pointing
                        // at paths that do not exist.
                        UITestFixtureMedia.reset()
                        let seedJournals = try JSONDecoder().decode([SeedJournal].self, from: seedData)
                        for seed in seedJournals {
                            let journal = Journal(name: seed.name)
                            journal.isPasswordProtected = seed.isPasswordProtected

                            // A protected journal is only unlockable if its
                            // password is in the Keychain, keyed by journal ID.
                            if let password = seed.password {
                                try? KeychainManager().savePassword(password, for: journal.id.uuidString)
                            }
                            for logSeed in seed.logs {
                                var mediaURLs = (logSeed.mediaURLs ?? []).compactMap(URL.init(string:))
                                for _ in 0..<(logSeed.photoCount ?? 0) {
                                    if let photoURL = UITestFixtureMedia.makePhoto() {
                                        mediaURLs.append(photoURL)
                                    }
                                }

                                let log = Log(
                                    title: logSeed.title,
                                    notes: logSeed.notes,
                                    mediaURLs: mediaURLs
                                )
                                log.latitude = logSeed.latitude
                                log.longitude = logSeed.longitude
                                log.altitude = logSeed.altitude

                                if let weatherSeed = logSeed.weather {
                                    log.weather = Weather(
                                        condition: weatherSeed.condition,
                                        temperature: weatherSeed.temperature,
                                        humidity: weatherSeed.humidity,
                                        windSpeed: weatherSeed.windSpeed,
                                        icon: weatherSeed.icon,
                                        aqi: weatherSeed.aqi,
                                        pm25: weatherSeed.pm25,
                                        pm10: weatherSeed.pm10
                                    )
                                }

                                for memoSeed in logSeed.audioMemos ?? [] {
                                    // A real file, so playback has something to open.
                                    guard let audioURL = UITestFixtureMedia.makeAudio(
                                        duration: memoSeed.duration
                                    ) else { continue }

                                    let memo = AudioMemo(
                                        title: memoSeed.title,
                                        audioURL: audioURL,
                                        transcription: memoSeed.transcription,
                                        duration: memoSeed.duration
                                    )
                                    memo.log = log
                                }

                                log.journal = journal
                                journal.logs.append(log)
                            }
                            context.insert(journal)
                        }
                        try context.save()
                    }
                } catch {
                    print("Failed to prepare UI test state: \(error)")
                }
            }

            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .onAppear {
                    // Disable animations during UI tests for faster, more reliable execution
                    if ProcessInfo.processInfo.arguments.contains("--uitesting") {
                        UIView.setAnimationsEnabled(false)
                        UIApplication.shared.connectedScenes
                            .compactMap { $0 as? UIWindowScene }
                            .flatMap { $0.windows }
                            .forEach { $0.layer.speed = 100 }
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
