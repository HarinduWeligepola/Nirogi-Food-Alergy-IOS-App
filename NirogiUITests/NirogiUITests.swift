//
//  NirogiUITests.swift
//  NirogiUITests
//
//  End-to-end interface tests driving the real app.
//
//  These exercise the complete pipeline — a real image goes through Vision,
//  the parser and the engine, and the resulting verdict is read back off
//  the screen. Nothing is mocked.
//
//  Created by Harindu Weligepola on 2026-10-10.
//

import XCTest

final class NirogiUITests: XCTestCase {

    private var app: XCUIApplication!

    /// Generous, because the first scan includes Vision warming up.
    private let scanTimeout: TimeInterval = 25

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        completeOnboardingIfPresented()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Onboarding

    /// Walks through onboarding when it appears.
    ///
    /// The app only shows this on a fresh install, so tests must cope with
    /// either state rather than assuming a clean database.
    private func completeOnboardingIfPresented() {
        let continueButton = app.buttons["Continue"]
        guard continueButton.waitForExistence(timeout: 5) else { return }

        continueButton.tap()

        // Choose two allergens so later assertions have something to find.
        for name in ["Dairy", "Peanut"] {
            let chip = app.buttons[name]
            if chip.waitForExistence(timeout: 3) { chip.tap() }
        }

        app.buttons["Continue"].tap()
        app.buttons["I understand — Start"].tap()
    }

    func testOnboardingLeadsToTheMainApp() {
        XCTAssertTrue(app.buttons["Scan"].waitForExistence(timeout: 5),
                      "The tab bar should be visible after onboarding")
        XCTAssertTrue(app.buttons["Home"].exists)
        XCTAssertTrue(app.buttons["Profile"].exists)
    }

    // MARK: - Navigation

    func testAllTabsAreReachable() {
        for tab in ["Scan", "Places", "Profile", "Home"] {
            app.buttons[tab].tap()
            XCTAssertTrue(app.buttons[tab].waitForExistence(timeout: 3),
                          "\(tab) tab should stay reachable")
        }
    }

    // MARK: - Scanning

    /// The core journey: scan a label that conflicts with the profile and
    /// confirm the app explains itself rather than just refusing.
    func testScanningAConflictingLabelShowsAvoidWithReasons() {
        openSample("Cream Biscuits")

        let verdict = app.staticTexts["Avoid"]
        XCTAssertTrue(verdict.waitForExistence(timeout: scanTimeout),
                      "A label with whey powder should be judged Avoid for a dairy profile")

        // The verdict must be justified, not bare.
        XCTAssertTrue(app.staticTexts["Why"].exists, "The reasons section must be shown")
        XCTAssertTrue(app.staticTexts["Dairy"].exists, "Dairy should be named as a reason")
    }

    /// A clean label must come back Safe, so the app is not simply
    /// pessimistic about everything.
    func testScanningACleanLabelShowsSafe() {
        openSample("Plain Rice Crackers")

        XCTAssertTrue(app.staticTexts["Safe"].waitForExistence(timeout: scanTimeout),
                      "A label with no conflicting ingredients should be Safe")
    }

    /// Regression guard for the false positive that would make the app
    /// unusable in Sri Lanka: "coconut milk" must not read as dairy.
    func testCoconutMilkIsNotReportedAsDairy() {
        openSample("Coconut Milk Powder")

        // This label does contain sodium caseinate, so Avoid is correct —
        // but the reason must never be the words "coconut milk".
        XCTAssertTrue(app.staticTexts["Avoid"].waitForExistence(timeout: scanTimeout))
        XCTAssertFalse(app.staticTexts["Found: \u{201C}coconut milk\u{201D}"].exists,
                       "Coconut milk must not be matched as dairy")
    }

    /// The raw OCR text must be inspectable, so a user can check the app's
    /// reading against the packet in their hand.
    func testRawScanTextCanBeInspected() {
        openSample("Cream Biscuits")
        XCTAssertTrue(app.staticTexts["Avoid"].waitForExistence(timeout: scanTimeout))

        let disclosure = app.staticTexts["What the scan saw"]
        XCTAssertTrue(disclosure.exists, "The raw text panel must be available")
    }

    // MARK: - Persistence

    /// A saved scan must survive the app being relaunched, which is the
    /// visible proof that persistence works.
    func testSavedScanSurvivesRelaunch() {
        openSample("Cream Biscuits")
        XCTAssertTrue(app.staticTexts["Avoid"].waitForExistence(timeout: scanTimeout))

        let saveButton = app.buttons["Save scan"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        app.terminate()
        app.launch()
        completeOnboardingIfPresented()

        app.buttons["Home"].tap()
        XCTAssertFalse(app.staticTexts["No scans yet"].exists,
                       "History should not be empty after saving and relaunching")
    }

    // MARK: - Profile

    func testProfileChangesArePersisted() {
        app.buttons["Profile"].tap()

        let cashewToggle = app.switches["Cashew"]
        XCTAssertTrue(cashewToggle.waitForExistence(timeout: 5))

        let wasOn = (cashewToggle.value as? String) == "1"
        cashewToggle.tap()

        app.terminate()
        app.launch()
        completeOnboardingIfPresented()
        app.buttons["Profile"].tap()

        let reloaded = app.switches["Cashew"]
        XCTAssertTrue(reloaded.waitForExistence(timeout: 5))
        XCTAssertNotEqual((reloaded.value as? String) == "1", wasOn,
                          "The toggle change should have been saved")
    }

    // MARK: - Helpers

    /// Opens the sample picker and scans the named label.
    private func openSample(_ title: String) {
        app.buttons["Scan"].tap()

        let sampleButton = app.buttons["Try a Sample"]
        XCTAssertTrue(sampleButton.waitForExistence(timeout: 5))
        sampleButton.tap()

        let sample = app.buttons.containing(.staticText, identifier: title).firstMatch
        XCTAssertTrue(sample.waitForExistence(timeout: 5), "Sample '\(title)' should be listed")
        sample.tap()
    }

    // MARK: - Performance

    /// Launch time is the first thing a user experiences, so it is
    /// measured rather than assumed.
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
