//
//  UITestSeedData.swift
//  EcoJournalUITests
//
//  Codable contract encoded into the UITEST_SEED_DATA launch environment
//  variable, read back by EcoJournal/Testing/UITestSeedData.swift in the app
//  target. Must stay structurally identical to that copy — the app and test
//  targets are separate processes and communicate only via this JSON shape,
//  not shared Swift types.
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
