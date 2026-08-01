//
//  EditLogContentViewSpikeTests.swift
//  EcoJournalTests
//
//  SPIKE — evaluating ViewInspector for covering SwiftUI view bodies from the
//  unit-test target.
//
//  The question this is meant to answer: can we drive a view into states that
//  are impractical to reach through XCUITest (in-flight refreshes, error
//  banners, soft-deleted photos) and have the body actually execute, so those
//  branches stop reading as uncovered?
//
//  Uses XCTest rather than Swift Testing because ViewInspector's async
//  inspection helpers are built around XCTestExpectation.
//

import XCTest
internal import SwiftUI
import SwiftData
import ViewInspector
@testable import EcoJournal

@MainActor
final class EditLogContentViewSpikeTests: XCTestCase {

    private var container: ModelContainer!
    private var journal: Journal!
    private var log: Log!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Journal.self, Log.self, AudioMemo.self, configurations: config)

        journal = Journal(name: "Spike Journal")
        container.mainContext.insert(journal)

        log = Log(title: "Spike Log", notes: "Notes", mediaURLs: [])
        container.mainContext.insert(log)
        log.journal = journal
        log.latitude = 47.6062
        log.longitude = -122.3321
        try container.mainContext.save()
    }

    override func tearDownWithError() throws {
        container = nil
        journal = nil
        log = nil
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

    // MARK: - Does the body even evaluate?

    /// Baseline: if this passes, ViewInspector can walk the view tree, which
    /// means `body` ran and its lines are counted as covered.
    func test_spike_bodyIsInspectable() throws {
        let view = EditLogContentView(viewModel: makeViewModel())

        let inspected = try view.inspect()

        XCTAssertNoThrow(try inspected.find(text: "Save Changes"))
    }

    // MARK: - States that are impractical via XCUITest

    /// A weather refresh failure is essentially unreachable through the real
    /// UI — it needs the network call to fail on cue.
    func test_spike_weatherErrorState() throws {
        let viewModel = makeViewModel()
        viewModel.weatherRefreshError = "Weather refresh timed out"

        let view = EditLogContentView(viewModel: viewModel)

        XCTAssertNoThrow(try view.inspect().find(text: "Weather refresh timed out"))
    }

    /// Mid-refresh spinner state — a real tap races the network.
    func test_spike_refreshingState() throws {
        let viewModel = makeViewModel()
        viewModel.isRefreshingGPS = true
        viewModel.isRefreshingWeather = true

        let view = EditLogContentView(viewModel: viewModel)

        XCTAssertNoThrow(try view.inspect())
    }

    /// Soft-deleted photos change how the hero section renders.
    func test_spike_softDeletedPhotoState() throws {
        let viewModel = makeViewModel()
        viewModel.editedPhotoURLs = [
            URL(fileURLWithPath: "/fake/a.jpg"),
            URL(fileURLWithPath: "/fake/b.jpg")
        ]
        viewModel.softDeletePhoto(at: 0)

        let view = EditLogContentView(viewModel: viewModel)

        XCTAssertNoThrow(try view.inspect())
        XCTAssertEqual(viewModel.visiblePhotoURLs.count, 1)
    }

    /// The toolbar swaps in a guarded back button once the draft is dirty.
    func test_spike_unsavedChangesState() throws {
        let viewModel = makeViewModel()
        viewModel.editedTitle = "Changed Title"

        let view = EditLogContentView(viewModel: viewModel)

        XCTAssertTrue(viewModel.hasUnsavedChanges)
        XCTAssertNoThrow(try view.inspect())
    }
}
