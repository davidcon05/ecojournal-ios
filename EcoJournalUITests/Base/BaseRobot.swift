//
//  BaseRobot.swift
//  EcoJournalUITests
//
//  Base robot class with common functionality
//

import XCTest

class BaseRobot {
    let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
        _ = app.exists  // Force snapshot for speed
    }

    // MARK: - Scroll Helpers

    /// Scroll to element, then tap it - use this for all tap actions
    @discardableResult
    func scrollToAndTap(_ element: XCUIElement) -> Self {
        element.scrollToElement()
        element.tap()
        return self 
    }

    /// Scroll to element, then verify it exists - use this for all existence assertions
    @discardableResult
    func scrollToAndVerifyExists(_ element: XCUIElement, message: String = "", file: StaticString = #file, line: UInt = #line) -> Self {
        element.scrollToElement()
        XCTAssertTrue(element.exists, message.isEmpty ? "Element should exist" : message, file: file, line: line)
        return self 
    }

    /// Scroll to element, then enter text
    @discardableResult
    func scrollToAndEnterText(_ element: XCUIElement, text: String) -> Self {
        element.scrollToElement()
        element.tap()
        element.typeText(text)
        return self 
    }
}
