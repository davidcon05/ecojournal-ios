//
//  BaseUITest.swift
//  EcoJournalUITests
//
//  Base test class for all UI tests
//

import XCTest
import CoreLocation

class BaseUITest: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        try super.setUpWithError()

        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]

        // Note: Location must be simulated via scheme settings or GPX file
        // For now, the app should handle missing location gracefully in tests
        //
        // Launch is intentionally NOT called here. Call launch() or
        // launch(seeding:) as the first line of each test method so every
        // test pays for exactly one app launch, never two.
    }

    override func tearDownWithError() throws {
        app = nil
        try super.tearDownWithError()
    }

    /// Launches the app, optionally with fixture data pre-seeded so tests
    /// can skip UI setup steps for preconditions that aren't the behavior
    /// under test. Do not seed for tests that verify the creation flow
    /// itself. See UITestSeedData.swift for the seed contract.
    @discardableResult
    func launch(seeding journals: [SeedJournal] = []) -> XCUIApplication {
        if !journals.isEmpty {
            let data = try! JSONEncoder().encode(journals)
            app.launchEnvironment["UITEST_SEED_DATA"] = String(data: data, encoding: .utf8)!
        }
        app.launch()
        return app
    }
}
