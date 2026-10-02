// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import XCTest

final class AppKitButtonViewTests: XCTestCase {
    @MainActor
    func testTextAndImageUseOneNativeButtonSurface() {
        let button = AppKitButtonView(frame: NSRect(x: 0, y: 0, width: 120, height: 32))
        let image = NSImage(size: NSSize(width: 12, height: 12))

        button.apply(
            text: "Save",
            image: image,
            imagePosition: .imageTrailing,
            imageScaling: .scaleProportionallyUpOrDown,
            font: .systemFont(ofSize: 15),
            textColor: .systemPurple,
            backgroundColor: .systemYellow,
            strokeColor: .systemBlue,
            lineWidth: 2,
            shape: .roundedRectangle(6),
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
            strokeColor: nil,
            lineWidth: 1,
            shape: .rectangle,
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

    /// A button's own fill keeps nine tenths of its opacity under the pointer, and all of it once the pointer leaves.
    @MainActor
    func testAButtonsOwnFillFadesUnderThePointer() throws {
        let button = AppKitButtonView()
        button.apply(
            text: "Save", image: nil, imagePosition: .noImage, imageScaling: .scaleNone,
            font: .systemFont(ofSize: 13), textColor: .labelColor, backgroundColor: .systemBlue, strokeColor: nil,
            lineWidth: 0, shape: .rectangle, lineBreakMode: .byTruncatingTail, enabled: true)
        let alpha = { Double(button.layer?.backgroundColor?.alpha ?? 0) }
        let crossing = { (type: NSEvent.EventType) in
            try XCTUnwrap(NSEvent.enterExitEvent(
                with: type, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
                eventNumber: 0, trackingNumber: 0, userData: nil))
        }

        button.mouseEntered(with: try crossing(.mouseEntered))
        XCTAssertEqual(alpha(), PressedFill.underPointer, accuracy: 0.001)

        button.mouseExited(with: try crossing(.mouseExited))
        XCTAssertEqual(alpha(), 1, accuracy: 0.001)
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
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
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
                .stroke: Brush.solidColor(Color("#FF0000")).propValue,
                .lineWidth: .number(2),
                .shape: ContainerShape.roundedRectangle(6).propValue,
            ]),
            button("stretched", icon(.stretch)),
            button("centred", icon(.center)),
            button("covering", icon(.fill)),
        ])
        renderer.applyForTesting(tree(stack))

        let padded = try XCTUnwrap(renderer.viewForTesting(id: .manual("padded")) as? NSButton)
        // A corner rounds no more than half the side it rounds: the button's sides are known once it is laid out.
        padded.frame.size = padded.fittingSize
        padded.layoutSubtreeIfNeeded()
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
