//
//  EditLogContentViewStateTests.swift
//  EcoJournalTests
//
//  SPIKE part 2 — can ViewInspector reach the *conditions a user would see*,
//  and act on them, rather than merely render the view?
//
//  Each test drives the view model into a state, then asserts on what the view
//  actually renders — including asserting that content is ABSENT in the
//  opposite state, which is what proves a branch was taken rather than just
//  evaluated.
//

import XCTest
internal import SwiftUI
import SwiftData
import ViewInspector
@testable import EcoJournal

@MainActor
final class EditLogContentViewStateTests: XCTestCase {

    private var container: ModelContainer!
    private var journal: Journal!
    private var log: Log!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Journal.self, Log.self, AudioMemo.self, configurations: config)

        journal = Journal(name: "State Journal")
        container.mainContext.insert(journal)

        log = Log(title: "State Log", notes: "Notes", mediaURLs: [])
        container.mainContext.insert(log)
        log.journal = journal
        log.latitude = 47.6062
        log.longitude = -122.3321
        try container.mainContext.save()
    }

    override func tearDownWithError() throws {
        container = nil; journal = nil; log = nil
        try super.tearDownWithError()
    }

    private func makeViewModel() -> EditLogViewModel {
        EditLogViewModel(
            log: log,
            journal: journal,
            modelContext: container.mainContext,
            locationManager: FakeLocationManager(),
            weatherService: MockWeatherService(),
            airQualityService: MockAirQualityService(),
            photoStorage: FakePhotoStorageService()
        )
    }

    // MARK: - Branch taken vs not taken

    /// The error banner must appear only in the failure state. Asserting it is
    /// absent otherwise is what distinguishes "branch taken" from "view
    /// happened to render".
    func test_weatherError_rendersOnlyWhenErrorPresent() throws {
        let clean = makeViewModel()
        XCTAssertThrowsError(
            try EditLogContentView(viewModel: clean).inspect().find(text: "Weather refresh timed out"),
            "Error text must not render when there is no error"
        )

        let failed = makeViewModel()
        failed.weatherRefreshError = "Weather refresh timed out"
        XCTAssertNoThrow(
            try EditLogContentView(viewModel: failed).inspect().find(text: "Weather refresh timed out"),
            "Error text must render when the refresh failed"
        )
    }

    /// The hero photo section is gated on there being photos at all.
    func test_heroSection_rendersOnlyWhenPhotosExist() throws {
        let withoutPhotos = makeViewModel()
        let emptyCount = try EditLogContentView(viewModel: withoutPhotos)
            .inspect().findAll(ViewType.Image.self).count

        let withPhotos = makeViewModel()
        withPhotos.editedPhotoURLs = [
            URL(fileURLWithPath: "/fake/a.jpg"),
            URL(fileURLWithPath: "/fake/b.jpg")
        ]
        let photoCount = try EditLogContentView(viewModel: withPhotos)
            .inspect().findAll(ViewType.Image.self).count

        XCTAssertGreaterThan(photoCount, emptyCount, "Photos should add rendered content")
    }

    // MARK: - Acting on the view, not just reading it

    /// Tapping the real Save button through the view — this executes the
    /// button's action closure, which is otherwise dead code.
    func test_tappingSave_appliesDraftToLog() throws {
        let viewModel = makeViewModel()
        viewModel.editedTitle = "Renamed By Inspector"

        let view = EditLogContentView(viewModel: viewModel)
        try view.inspect().find(button: "Save Changes").tap()

        XCTAssertEqual(log.title, "Renamed By Inspector")
        XCTAssertTrue(viewModel.shouldDismiss)
    }

    /// The delete button should not destroy anything without confirmation.
    func test_tappingDelete_doesNotDeleteWithoutConfirmation() throws {
        let viewModel = makeViewModel()

        let view = EditLogContentView(viewModel: viewModel)
        try view.inspect().find(button: "Delete Log Entry").tap()

        let remaining = try container.mainContext.fetch(FetchDescriptor<Log>())
        XCTAssertEqual(remaining.count, 1, "Delete must require typed confirmation")
        XCTAssertFalse(viewModel.shouldDismiss)
    }

    // MARK: - Content reflects state

    func test_titleField_reflectsDraftTitle() throws {
        let viewModel = makeViewModel()
        viewModel.editedTitle = "Draft Title"

        let view = EditLogContentView(viewModel: viewModel)
        let field = try view.inspect().find(ViewType.TextField.self)

        XCTAssertEqual(try field.input(), "Draft Title")
    }

    /// A log that carries weather renders its capture timestamp; one without
    /// does not.
    func test_captureTimestamp_rendersOnlyWithWeather() throws {
        let withoutWeather = makeViewModel()
        XCTAssertThrowsError(
            try EditLogContentView(viewModel: withoutWeather)
                .inspect().find(textWhere: { text, _ in text.hasPrefix("CAPTURED AT") })
        )

        log.weather = Weather(condition: "Clear", temperature: 70, humidity: 40, windSpeed: 3, icon: "01d")
        let withWeather = makeViewModel()
        XCTAssertNoThrow(
            try EditLogContentView(viewModel: withWeather)
                .inspect().find(textWhere: { text, _ in text.hasPrefix("CAPTURED AT") })
        )
    }

    // MARK: - Boundary: does ViewInspector respect .disabled()?

    /// The Save button is `.disabled(!viewModel.isValid)`. A real user cannot
    /// tap it with an empty title. If ViewInspector taps it anyway, then it
    /// bypasses hit-testing/enablement — which is precisely the class of bug
    /// that made the password sheet's disabled Unlock button so confusing.
    func test_boundary_tappingDisabledSaveButton() throws {
        let viewModel = makeViewModel()
        viewModel.editedTitle = ""              // invalid -> Save is disabled
        XCTAssertFalse(viewModel.isValid)

        let view = EditLogContentView(viewModel: viewModel)
        // Separate "couldn't find the button" from "found it and refused to
        // fire a disabled action" — the earlier `try?` conflated the two.
        let button = try view.inspect().find(button: "Save Changes")

        var tapThrew = false
        do { try button.tap() } catch { tapThrew = true }

        XCTAssertFalse(
            viewModel.shouldDismiss,
            "ViewInspector fired a DISABLED button's action — it does not model enablement"
        )
        XCTAssertTrue(
            tapThrew,
            "Expected tap() to throw on a disabled button; if it did not throw yet also did not act, the mechanism is something else"
        )
    }
}
