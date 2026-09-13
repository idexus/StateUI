// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@testable import StateUIAppKit
import XCTest

final class AppKitButtonViewTests: XCTestCase {
    @MainActor
    func testTextAndImageUseOneNativeButtonSurface() {
        let button = AppKitButtonView()
        let image = NSImage(size: NSSize(width: 12, height: 12))

        button.apply(
            text: "Save",
            image: image,
            imagePosition: .imageTrailing,
            imageScaling: .scaleProportionallyUpOrDown,
            font: .systemFont(ofSize: 15),
            textColor: .systemPurple,
            backgroundColor: .systemYellow,
            borderColor: .systemBlue,
            borderWidth: 2,
            cornerRadius: 6,
            lineBreakMode: .byTruncatingTail,
            enabled: false)

        XCTAssertEqual(button.title, "Save")
        XCTAssertTrue(button.image === image)
        XCTAssertEqual(button.imagePosition, .imageTrailing)
        XCTAssertEqual(button.imageScaling, .scaleProportionallyUpOrDown)
        XCTAssertEqual(button.font?.pointSize, 15)
        XCTAssertFalse(button.isEnabled)
        XCTAssertEqual(button.layer?.cornerRadius, 6)
        XCTAssertEqual(button.layer?.borderWidth, 2)
    }

    @MainActor
    func testImageOnlyButtonHasNoInventedCaption() {
        let button = AppKitButtonView()
        button.apply(
            text: "",
            image: NSImage(size: NSSize(width: 16, height: 16)),
            imagePosition: .imageOnly,
            imageScaling: .scaleNone,
            font: .systemFont(ofSize: 13),
            textColor: .controlTextColor,
            backgroundColor: nil,
            borderColor: nil,
            borderWidth: 0,
            cornerRadius: 0,
            lineBreakMode: .byClipping,
            enabled: true)

        XCTAssertEqual(button.title, "")
        XCTAssertEqual(button.imagePosition, .imageOnly)
        XCTAssertTrue(button.isEnabled)
    }

    @MainActor
    func testPointerPhasesAndClickAreReportedExactlyOnce() {
        let button = AppKitButtonView()
        var events: [String] = []
        button.onPressed = { events.append("pressed") }
        button.onClicked = { events.append("clicked") }
        button.onReleased = { events.append("released") }

        button.clickForTesting()

        XCTAssertEqual(events, ["pressed", "clicked", "released"])
    }
}

#endif
