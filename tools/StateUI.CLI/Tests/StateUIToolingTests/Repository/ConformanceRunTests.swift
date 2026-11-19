// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import XCTest

final class TestRunTests: XCTestCase {
    /// A run counts where XCTest or Swift Testing says a test ran, or a parallel run says it tests one; a run of none
    /// does not.
    func testARunOfNoneIsNoRun() {
        XCTAssertTrue(TestRun.ranAny(["\t Executed 0 tests, with 0 failures", "\t Executed 2 tests, with 0 failures (0 unexpected)"]))
        XCTAssertTrue(TestRun.ranAny(["✔ Test run with 3 tests in 1 suite passed after 0.002 seconds."]))
        XCTAssertFalse(TestRun.ranAny(["\t Executed 0 tests, with 0 failures", "✔ Test run with 0 tests in 0 suites passed after 0.001 seconds."]))
        XCTAssertTrue(TestRun.ranAny(["[1/3] Testing StateUIWinUITests.WinUIConformanceTests/testButton"]))
        XCTAssertFalse(TestRun.ranAny(["\t Executed 0 tests, with 0 failures (0 unexpected) in 0.000 (0.000) seconds"]))
        XCTAssertFalse(TestRun.ranAny(["Build complete!"]))
    }
}

final class ConformanceRunTests: XCTestCase {
    /// A host's suite is filtered to whole families: SwiftPM's expression takes each family's test and its parts
    /// alone, the UIKit and Android test applications each family's name, the Web suite the families by name.
    func testAFilterTakesWholeFamilies() {
        XCTAssertEqual(ConformanceRun.filter(for: .appkit, families: nil), "AppKitConformanceTests|AppKitDeclarationExportTests")
        XCTAssertEqual(ConformanceRun.filter(for: .android, families: nil), "AndroidConformanceTests,AndroidDeclarationExportTests")
        XCTAssertEqual(ConformanceRun.filter(for: .web, families: nil), "WebConformanceTests")
        XCTAssertEqual(ConformanceRun.filter(for: .winui, families: ["Button", "VisualElement"]),
                       "WinUIConformanceTests/test(Button|VisualElement)[0-9]*$")
        XCTAssertEqual(ConformanceRun.filter(for: .android, families: ["Slider", "Text"]),
                       "AndroidConformanceTests.testSlider,AndroidConformanceTests.testText")
        XCTAssertEqual(ConformanceRun.filter(for: .web, families: ["Button"]), "Button")
    }

    /// A verdict file taken off a device is of its family, a part's too.
    func testAVerdictFileIsOfItsFamily() {
        XCTAssertEqual(AndroidSuite.family(of: "Button.txt"), "Button")
        XCTAssertEqual(AndroidSuite.family(of: "VisualElement-12.txt"), "VisualElement")
        XCTAssertEqual(AndroidSuite.family(of: "Date-Picker.txt"), "Date-Picker")
    }
}
