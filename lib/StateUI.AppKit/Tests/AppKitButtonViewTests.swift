// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
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

    /// The side of its caption an icon stands on reaches the native button.
    /// Leading and trailing are AppKit's own sides of a line, which follow
    /// the layout direction.
    @MainActor
    func testAButtonsIconPositionComesThroughTheHost() throws {
        let renderer = AppKitRenderer.running {
            VStack {
                Button("Leading").icon("save.png").iconPosition(.leading)
                Button("Top").icon("save.png").iconPosition(.top)
                Button("Trailing").icon("save.png").iconPosition(.trailing)
                Button("Bottom").icon("save.png").iconPosition(.bottom)
            }
        }
        defer { renderer.closeForTesting() }
        let buttons = renderer.nativeViews(AppKitButtonView.self)

        XCTAssertEqual(
            buttons.map { $0.imagePosition },
            [.imageLeading, .imageAbove, .imageTrailing, .imageBelow])
    }

    /// What happens to a caption too long for its button reaches the native
    /// cell.
    @MainActor
    func testAButtonsLineBreakReachesItsNativeCell() throws {
        let renderer = AppKitRenderer.running {
            VStack {
                Button("Clip").lineBreak(.noWrap)
                Button("Words").lineBreak(.wordWrap)
                Button("Characters").lineBreak(.characterWrap)
                Button("Head").lineBreak(.headTruncation)
                Button("Tail").lineBreak(.tailTruncation)
                Button("Middle").lineBreak(.middleTruncation)
            }
        }
        defer { renderer.closeForTesting() }
        let buttons = renderer.nativeViews(AppKitButtonView.self)

        XCTAssertEqual(buttons.map { $0.cell?.lineBreakMode }, [
            .byClipping, .byWordWrapping, .byCharWrapping,
            .byTruncatingHead, .byTruncatingTail, .byTruncatingMiddle,
        ])
    }
}

#endif
