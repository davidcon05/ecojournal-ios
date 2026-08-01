//
//  SortOptionTests.swift
//  EcoJournalTests
//
//  The two sort enums drive FilterSheet, which renders each case's rawValue,
//  systemImage, and subtitle directly. A case with a missing or duplicated
//  display value shows up as a broken row rather than a crash, so the values
//  are worth pinning down.
//

import Testing
import Foundation
@testable import EcoJournal

@Suite("Sort Option Tests")
struct SortOptionTests {

    // MARK: - SortOption (journals)

    @Test("Every journal sort option is available to the filter sheet")
    func sortOption_hasAllFourCases() {
        #expect(SortOption.allCases.count == 4)
    }

    @Test(
        "Journal sort options carry their display name",
        arguments: [
            (SortOption.mostRecent, "Most Recent"),
            (SortOption.oldestFirst, "Oldest First"),
            (SortOption.aToZ, "A → Z"),
            (SortOption.zToA, "Z → A")
        ]
    )
    func sortOption_rawValueIsDisplayName(option: SortOption, expected: String) {
        #expect(option.rawValue == expected)
        #expect(option.id == expected)
    }

    @Test("Each journal sort option has a distinct icon")
    func sortOption_iconsAreDistinct() {
        let icons = Set(SortOption.allCases.map(\.systemImage))
        #expect(icons.count == SortOption.allCases.count)
        #expect(icons.contains("") == false)
    }

    @Test("Journal sort options have no subtitle")
    func sortOption_hasNoSubtitle() {
        for option in SortOption.allCases {
            #expect(option.subtitle == nil)
        }
    }

    @Test("Journal sort options round-trip through their raw value")
    func sortOption_roundTrips() throws {
        for option in SortOption.allCases {
            #expect(SortOption(rawValue: option.rawValue) == option)
        }
    }

    // MARK: - LogSortOption (logs)

    @Test("Every log sort option is available to the filter sheet")
    func logSortOption_hasAllThreeCases() {
        #expect(LogSortOption.allCases.count == 3)
    }

    @Test(
        "Log sort options carry their display name",
        arguments: [
            (LogSortOption.creationDate, "Creation Date"),
            (LogSortOption.aToZ, "A → Z"),
            (LogSortOption.zToA, "Z → A")
        ]
    )
    func logSortOption_rawValueIsDisplayName(option: LogSortOption, expected: String) {
        #expect(option.rawValue == expected)
        #expect(option.id == expected)
    }

    @Test("Each log sort option has a distinct icon")
    func logSortOption_iconsAreDistinct() {
        let icons = Set(LogSortOption.allCases.map(\.systemImage))
        #expect(icons.count == LogSortOption.allCases.count)
    }

    /// Only the date option explains itself; the alphabetical ones are
    /// self-evident from their name.
    @Test("Only the creation-date option carries a subtitle")
    func logSortOption_subtitleOnlyOnCreationDate() {
        #expect(LogSortOption.creationDate.subtitle == "By date created")
        #expect(LogSortOption.aToZ.subtitle == nil)
        #expect(LogSortOption.zToA.subtitle == nil)
    }

    @Test("Log sort options round-trip through their raw value")
    func logSortOption_roundTrips() {
        for option in LogSortOption.allCases {
            #expect(LogSortOption(rawValue: option.rawValue) == option)
        }
    }
}
