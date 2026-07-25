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
                        let seedJournals = try JSONDecoder().decode([SeedJournal].self, from: seedData)
                        for seed in seedJournals {
                            let journal = Journal(name: seed.name)
                            journal.isPasswordProtected = seed.isPasswordProtected
                            for logSeed in seed.logs {
                                let log = Log(title: logSeed.title, notes: logSeed.notes)
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
