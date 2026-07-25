//
//  DashboardTests.swift
//  EcoJournalUITests
//
//  Tests for Dashboard functionality
//

import XCTest

final class DashboardTests: BaseUITest {

    // MARK: - Empty State Tests

    func test_dashboard_showsEmptyState_whenNoJournals() {
        launch()

        DashboardRobot(app: app)
            .verifyEmptyState()
            .verifyDashboardTitle()
    }

    // MARK: - Journal Creation Tests
    // Not seeded: these tests verify the creation flow itself.

    func test_createJournal_successfullyCreatesJournal() {
        launch()

        DashboardRobot(app: app)
            .tapNewJournal()

        CreateJournalRobot(app: app)
            .enterName("Test Journal")
            .tapCreate()

        DashboardRobot(app: app)
            .waitForDashboard()
            .verifyJournalExists(named: "Test Journal")
    }

    func test_createJournal_createButtonDisabled_whenNameIsEmpty() {
        launch()

        DashboardRobot(app: app)
            .tapNewJournal()

        CreateJournalRobot(app: app)
            .verifyCreateButtonEnabled(false)
    }

    func test_createMultipleJournals_allAppearOnDashboard() {
        launch()

        // Create first journal
        DashboardRobot(app: app)
            .tapNewJournal()

        CreateJournalRobot(app: app)
            .enterName("Journal One")
            .tapCreate()

        DashboardRobot(app: app)
            .verifyJournalExists(named: "Journal One")
            .tapNewJournal()

        CreateJournalRobot(app: app)
            .enterName("Journal Two")
            .tapCreate()

        DashboardRobot(app: app)
            .verifyJournalExists(named: "Journal One")
            .verifyJournalExists(named: "Journal Two")
            .tapNewJournal()

        CreateJournalRobot(app: app)
            .enterName("Journal Three")
            .tapCreate()

        DashboardRobot(app: app)
            .verifyJournalExists(named: "Journal One")
            .verifyJournalExists(named: "Journal Two")
            .verifyJournalExists(named: "Journal Three")
    }

    // MARK: - Search Tests

    func test_searchJournals_findsMatchingJournal() {
        launch(seeding: [
            SeedJournal(name: "Olympic National Park", isPasswordProtected: false, logs: [])
        ])

        DashboardRobot(app: app)
            .waitForDashboard()
            .searchFor("Olympic")
            .verifySearchResults(contain: "Olympic National Park")
    }

    func test_searchJournals_filtersResults() {
        launch(seeding: [
            SeedJournal(name: "Olympic National Park", isPasswordProtected: false, logs: []),
            SeedJournal(name: "Yellowstone National Park", isPasswordProtected: false, logs: [])
        ])

        DashboardRobot(app: app)
            .waitForDashboard()
            .searchFor("Olympic")
            .verifySearchResults(contain: "Olympic National Park")
            .verifyJournalDoesNotExist(named: "Yellowstone National Park")
    }

    // MARK: - Dropdown Autocomplete Tests

    func test_searchDropdown_showsSuggestions_whenTyping() {
        launch(seeding: [
            SeedJournal(name: "Olympic National Park", isPasswordProtected: false, logs: []),
            SeedJournal(name: "Olympia State Forest", isPasswordProtected: false, logs: [])
        ])

        DashboardRobot(app: app)
            .waitForDashboard()
            .searchFor("Oly")
            .verifyDropdownIsVisible()
            .verifySearchSuggestionExists("Olympic National Park")
            .verifySearchSuggestionExists("Olympia State Forest")
    }

    func test_searchDropdown_filtersSuggestions_basedOnInput() {
        launch(seeding: [
            SeedJournal(name: "Olympic National Park", isPasswordProtected: false, logs: []),
            SeedJournal(name: "Yellowstone National Park", isPasswordProtected: false, logs: [])
        ])

        DashboardRobot(app: app)
            .waitForDashboard()
            .searchFor("Olympic")
            .verifyDropdownIsVisible()
            .verifySearchSuggestionExists("Olympic National Park")
            .verifySearchSuggestionDoesNotExist("Yellowstone National Park")
    }

    func test_searchDropdown_selectingSuggestion_navigatesToJournal() {
        launch(seeding: [
            SeedJournal(name: "Olympic National Park", isPasswordProtected: false, logs: [])
        ])

        DashboardRobot(app: app)
            .waitForDashboard()
            .searchFor("Oly")
            .verifyDropdownIsVisible()
            .tapSearchSuggestion("Olympic National Park")

        // Verify navigation to journal
        JournalRobot(app: app)
            .verifyJournalTabView()
    }

    func test_searchDropdown_hidesWhenSearchIsCleared() {
        launch(seeding: [
            SeedJournal(name: "Olympic National Park", isPasswordProtected: false, logs: [])
        ])

        DashboardRobot(app: app)
            .waitForDashboard()
            .searchFor("Oly")
            .verifyDropdownIsVisible()
            .clearSearch()
            .verifyDropdownIsHidden()
    }

    func test_searchDropdown_prioritizesPrefixMatches() {
        // "Mount Rainier" should appear first (prefix match), then "Rocky Mountains" (contains match)
        // "Olympic Peninsula" should not appear (doesn't contain "mount")
        launch(seeding: [
            SeedJournal(name: "Mount Rainier", isPasswordProtected: false, logs: []),
            SeedJournal(name: "Rocky Mountains", isPasswordProtected: false, logs: []),
            SeedJournal(name: "Olympic Peninsula", isPasswordProtected: false, logs: [])
        ])

        DashboardRobot(app: app)
            .waitForDashboard()
            .searchFor("Mount")
            .verifyDropdownIsVisible()
            .verifySearchSuggestionExists("Mount Rainier") // Prefix match - should appear first
            .verifySearchSuggestionExists("Rocky Mountains") // Contains match - should appear second
            .verifySearchSuggestionDoesNotExist("Olympic Peninsula") // No match
    }

    // MARK: - Navigation Tests

    func test_selectJournal_navigatesToJournalTabs() {
        launch(seeding: [
            SeedJournal(name: "Test Journal", isPasswordProtected: false, logs: [])
        ])

        DashboardRobot(app: app)
            .waitForDashboard()
            .selectJournal(named: "Test Journal")

        // Test: Verify journal tab view
        JournalRobot(app: app)
            .verifyJournalTabView()
    }

    func test_navigateToJournal_andBack() {
        launch(seeding: [
            SeedJournal(name: "Test Journal", isPasswordProtected: false, logs: [])
        ])

        DashboardRobot(app: app)
            .waitForDashboard()
            .selectJournal(named: "Test Journal")

        // Test: Navigate in and back out
        JournalRobot(app: app)
            .verifyJournalTabView()
            .navigateBack()

        DashboardRobot(app: app)
            .verifyDashboardTitle()
            .verifyJournalExists(named: "Test Journal")
    }
}
