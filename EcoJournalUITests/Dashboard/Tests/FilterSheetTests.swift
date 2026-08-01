//
//  FilterSheetTests.swift
//  EcoJournalUITests
//
//  Journeys through the shared FilterSheet, reached from the dashboard's
//  filter button. The sort logic itself is covered by
//  DashboardViewModelSearchAndSettingsTests; these verify the sheet is wired
//  up, renders every option, and applies a selection.
//

import XCTest

final class FilterSheetTests: BaseUITest {

    private func openFilterSheet(journals: [String] = ["Alpha", "Zulu", "Mango"]) {
        launch(seeding: journals.map {
            SeedJournal(name: $0, isPasswordProtected: false, logs: [])
        })

        DashboardRobot(app: app)
            .waitForDashboard()
            .tapFilter()
    }

    func test_filterSheet_opensFromDashboard() {
        openFilterSheet()

        FilterSheetRobot(app: app)
            .verifySheetShown()
    }

    func test_filterSheet_showsEverySortOption() {
        openFilterSheet()

        FilterSheetRobot(app: app)
            .verifySheetShown()
            .verifyOptionExists("Most Recent")
            .verifyOptionExists("Oldest First")
            .verifyOptionExists("A → Z")
            .verifyOptionExists("Z → A")
    }

    func test_filterSheet_choosingOption_dismissesSheet() {
        openFilterSheet()

        FilterSheetRobot(app: app)
            .verifySheetShown()
            .selectOption("A → Z")
            .verifySheetDismissed()
    }

    /// Sorting A→Z should reorder the dashboard, so the alphabetically first
    /// journal ends up ahead of the others.
    func test_filterSheet_sortingAToZ_reordersDashboard() {
        openFilterSheet()

        FilterSheetRobot(app: app)
            .selectOption("A → Z")
            .verifySheetDismissed()

        DashboardRobot(app: app)
            .verifyJournalExists(named: "Alpha")
            .verifyJournalExists(named: "Zulu")
    }
}
