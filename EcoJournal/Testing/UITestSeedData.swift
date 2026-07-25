//
//  UITestSeedData.swift
//  EcoJournal
//
//  Codable contract decoded from the UITEST_SEED_DATA launch environment
//  variable (see EcoJournalApp.swift). Must stay structurally identical to
//  the copy in EcoJournalUITests/Base/UITestSeedData.swift — the app and
//  test targets are separate processes and communicate only via this JSON
//  shape, not shared Swift types.
//

import Foundation

struct SeedJournal: Codable {
    let name: String
    let isPasswordProtected: Bool
    let logs: [SeedLog]
}

struct SeedLog: Codable {
    let title: String
    let notes: String
}
