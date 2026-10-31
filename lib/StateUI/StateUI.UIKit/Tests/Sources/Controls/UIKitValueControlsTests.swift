// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
import XCTest

/// A value in a range on UIKit's controls, by the host layer's arithmetic (`ValueArithmetic`).
@MainActor
final class UIKitValueControlsTests: XCTestCase {
    /// A range the tree gives the wrong way round stands the lower end first, and a step that is no positive number
    /// moves by one - as on every host.
    @MainActor
    func testAReversedRangeStandsInOrderAndAStepThatCannotMoveIsOne() {
        let slider = UIKitSliderView()
        slider.apply(value: 5, minimum: 10, maximum: 0)
        XCTAssertEqual([slider.minimumValue, slider.maximumValue], [0, 10])

        let stepper = UIKitStepperView()
        stepper.apply(value: 5, minimum: 10, maximum: 0, step: .infinity)
        XCTAssertEqual([stepper.minimumValue, stepper.maximumValue, stepper.stepValue], [0, 10, 1])
    }

    /// A switch and a check box say the words the tree gives them, in their case: the check box as its own title;
    /// the switch's beside it at its start, the switch at its end, naming it for VoiceOver and flipping it at a tap.
    @MainActor
    func testATogglesWordsStandBesideIt() throws {
        let on = State(wrappedValue: false)
        let host = UIKitRenderer.running {
            VStack {
                Switch(on.projectedValue).text("Wi-Fi")
                CheckBox(true).text("agree").textCase(.uppercase)
            }
        }
        defer { host.finish() }
        let toggle = try XCTUnwrap(host.views(UIKitSwitchView.self).first)
        let box = try XCTUnwrap(host.views(UIKitCheckView.self).first)

        XCTAssertEqual(box.configuration?.title, "AGREE")
        XCTAssertEqual(toggle.caption.text, "Wi-Fi")
        XCTAssertEqual(toggle.control.accessibilityLabel, "Wi-Fi", "the switch named by its words")
        toggle.frame = CGRect(x: 0, y: 0, width: 300, height: 40)
        toggle.layoutIfNeeded()
        XCTAssertEqual(toggle.control.frame.maxX, 300, "the switch at the end")
        XCTAssertEqual(toggle.caption.frame.minX, 0, "the words from the start")

        toggle.tapWordsForTesting()
        host.settle { on.wrappedValue }
        XCTAssertTrue(on.wrappedValue, "a tap on the words flips it")
    }

    /// A slider pressed is released however the touch ends - lifted inside, outside, or taken by the system's own
    /// gesture: no press stands with no release after it.
    @MainActor
    func testASliderPressedIsReleasedHoweverTheTouchEnds() {
        for ending: UIControl.Event in [.touchUpInside, .touchUpOutside, .touchCancel] {
            let slider = UIKitSliderView()
            var heard: [String] = []
            slider.onPressed = { heard.append("pressed") }
            slider.onReleased = { heard.append("released") }

            slider.sendActions(for: .touchDown)
            slider.sendActions(for: ending)

            XCTAssertEqual(heard, ["pressed", "released"], "ended by \(ending.rawValue)")
        }
    }

    /// A picker is made as its presentation's control - a pop-up button, a segmented control, a column of buttons
    /// marked as radio buttons - each offering the values and taking the user's choice as its value.
    @MainActor
    func testEachPresentationMakesItsOwnControl() throws {
        let size = State<String?>(wrappedValue: nil)
        let host = UIKitRenderer.running {
            VStack {
                Picker(["Small", "Medium", "Large"], selection: size.projectedValue)
                Picker(["One", "Two"], selection: size.projectedValue).presentation(.segmented)
                Picker(["Small", "Medium", "Large"], selection: size.projectedValue).presentation(.radio)
            }
        }
        defer { host.finish() }

        XCTAssertEqual(host.views(UIKitPickerView.self).map(\.choices), [["Small", "Medium", "Large"]])
        let segments = try XCTUnwrap(host.views(UIKitSegmentedPickerView.self).first)
        XCTAssertEqual((0..<segments.numberOfSegments).map { segments.titleForSegment(at: $0) }, ["One", "Two"])
        let radio = try XCTUnwrap(host.views(UIKitRadioPickerView.self).first)
        XCTAssertEqual(radio.arrangedSubviews.count, 3)
        host.layOut()
        let rows = radio.arrangedSubviews.map(\.frame)
        XCTAssertTrue(zip(rows, rows.dropFirst()).allSatisfy { $0.maxY <= $1.minY + 0.5 }, "one under another: \(rows)")

        radio.userChose(1)
        XCTAssertEqual(size.wrappedValue, "Medium")
        host.settle { radio.chosen == 1 }
        let marked = radio.arrangedSubviews.compactMap { ($0 as? UIButton)?.accessibilityTraits.contains(.selected) }
        XCTAssertEqual(marked, [false, true, false], "the chosen one read as selected")
    }
}
