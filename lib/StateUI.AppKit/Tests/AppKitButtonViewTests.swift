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

    /// A button keeps its padding around its caption and draws its outline
    /// and corners as written. Its icon is stretched, stands at its own size,
    /// or is fitted - which is also what a covering aspect does on a button.
    @MainActor
    func testAButtonsPaddingOutlineAndIconAspectComeThroughTheHost() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        func button(_ id: String, _ properties: [Prop: HostValue]) -> HostPatch {
            var button = HostPatch(id: .manual(id), type: .button)
            button.properties = properties
            return button
        }
        func icon(_ aspect: Aspect) -> [Prop: HostValue] {
            [.icon: .string("save.png"), .aspect: .enumeration(aspect.rawValue)]
        }
        var stack = HostPatch(id: .manual("stack"), type: .vStack)
        stack.children = .arranged([
            button("padded", [
                .text: .string("Save"),
                .padding: .numbers([20, 10, 20, 10]),
                .borderColor: .color(red: 255, green: 0, blue: 0, alpha: 255),
                .borderWidth: .number(2),
                .cornerRadius: .number(6),
            ]),
            button("stretched", icon(.stretch)),
            button("centred", icon(.center)),
            button("covering", icon(.fill)),
        ])
        renderer.applyForTesting(tree(stack))

        let padded = try XCTUnwrap(renderer.viewForTesting(id: .manual("padded")) as? NSButton)
        let intrinsic = padded.intrinsicContentSize
        XCTAssertEqual(padded.fittingSize.width, intrinsic.width + 40, accuracy: 0.5)
        XCTAssertEqual(padded.fittingSize.height, intrinsic.height + 20, accuracy: 0.5)
        let outline = try XCTUnwrap(padded.layer)
        assertChannels(channels(outline.borderColor), [1, 0, 0, 1])
        XCTAssertEqual(outline.borderWidth, 2)
        XCTAssertEqual(outline.cornerRadius, 6)

        func scaling(_ id: String) -> NSImageScaling? {
            (renderer.viewForTesting(id: .manual(id)) as? NSButton)?.imageScaling
        }
        XCTAssertEqual(scaling("stretched"), .scaleAxesIndependently)
        XCTAssertEqual(scaling("centred"), .scaleNone)
        XCTAssertEqual(scaling("covering"), .scaleProportionallyUpOrDown)
    }
}

#endif
