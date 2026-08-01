//
//  FilterSheetRobot.swift
//  EcoJournalUITests
//
//  Robot pattern for the shared FilterSheet.
//

import XCTest

final class FilterSheetRobot: BaseRobot {
    private let screen: FilterSheetScreen

    override init(app: XCUIApplication) {
        self.screen = FilterSheetScreen(app: app)
        super.init(app: app)
    }

    @discardableResult
    func verifySheetShown() -> Self {
        XCTAssertTrue(screen.header.waitForExistence(timeout: 5), "Filter sheet should be shown")
        return self
    }

    @discardableResult
    func verifyOptionExists(_ name: String) -> Self {
        XCTAssertTrue(
            screen.option(name).waitForExistence(timeout: 5),
            "Sort option '\(name)' should exist"
        )
        return self
    }

    @discardableResult
    func selectOption(_ name: String) -> Self {
        let option = screen.option(name)
        XCTAssertTrue(option.waitForExistence(timeout: 5), "Sort option '\(name)' should exist")
        option.tap()
        return self
    }

    @discardableResult
    func verifySheetDismissed() -> Self {
        XCTAssertTrue(
            screen.header.waitForNonExistence(timeout: 5),
            "Filter sheet should close after choosing an option"
        )
        return self
    }
}
