// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import StateUIConformance
import XCTest

@MainActor
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
            tracking: 2,
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
        XCTAssertEqual(button.attributedTitle.attribute(.kern, at: 0, effectiveRange: nil) as? Double, 2)
        XCTAssertFalse(button.isEnabled)
        XCTAssertEqual(button.layer?.cornerRadius, 6)
        XCTAssertEqual(button.layer?.borderWidth, 2)
    }

    /// A button wider than its words keeps its icon beside them, the two in the middle together - not the icon at
    /// the button's edge and the words alone in the middle.
    @MainActor
    func testAWideButtonsIconStandsBesideItsWords() throws {
        for position in [NSControl.ImagePosition.imageLeading, .imageTrailing] {
            let button = AppKitButtonView(frame: NSRect(x: 0, y: 0, width: 300, height: 32))
            button.apply(
                text: "Log out", image: NSImage(size: NSSize(width: 16, height: 16)), imagePosition: position,
                imageScaling: .scaleProportionallyDown, font: .systemFont(ofSize: 13), textColor: .labelColor,
                tracking: 0, backgroundColor: nil, strokeColor: nil, lineWidth: 0, shape: .rectangle,
                lineBreakMode: .byTruncatingTail, enabled: true)
            let cell = try XCTUnwrap(button.cell as? NSButtonCell)
            let image = cell.imageRect(forBounds: button.bounds)
            let words = cell.titleRect(forBounds: button.bounds)
            let gap = position == .imageLeading ? words.minX - image.maxX : image.minX - words.maxX

            XCTAssertLessThan(gap, 12, "\(position.rawValue): the icon \(image) apart from its words \(words)")
        }
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
            tracking: 0,
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

    /// A disabled button hears no press: a real mouse-down reaches AppKit's own check, which lets nothing through.
    @MainActor
    func testADisabledButtonHearsNoPress() throws {
        let button = AppKitButtonView()
        button.isEnabled = false
        var events: [String] = []
        button.onPressed = { events.append("pressed") }
        button.onReleased = { events.append("released") }
        let down = try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
            eventNumber: 0, clickCount: 1, pressure: 1))

        button.mouseDown(with: down)

        XCTAssertEqual(events, [])
    }

    /// A button's own fill keeps nine tenths of its opacity under the pointer, and all of it once the pointer leaves.
    @MainActor
    func testAButtonsOwnFillFadesUnderThePointer() throws {
        let button = AppKitButtonView()
        button.apply(
            text: "Save", image: nil, imagePosition: .noImage, imageScaling: .scaleNone,
            font: .systemFont(ofSize: 13), textColor: .labelColor, tracking: 0, backgroundColor: .systemBlue,
            strokeColor: nil,
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

    /// A button's padding keeps what it shows clear of its edges: a picture alone in a stated size fits the room
    /// inside the padding, not the whole button.
    @MainActor
    func testAButtonsPaddingKeepsItsPictureClearOfItsEdges() throws {
        stateUIUseApp(OneWindowApplication(page: {
            VStack {
                Button(icon: ImageSource("test_wide.svg")).contentMode(.fit).width(64).height(64).padding(12)
                    .background(Color("#FFFFFF")).shape(.roundedRectangle(12))
            }
            .horizontalAlignment(.start)
            .verticalAlignment(.start)
        }))
        let renderer = testRenderer(resourceDirectory: AppKitDriver.pictures, presentsWindows: false)
        renderer.startForTesting()
        defer { renderer.closeForTesting() }
        let button = try XCTUnwrap(renderer.nativeViews(AppKitButtonView.self).first)
        renderer.windowsForTesting.first?.window?.contentView?.layoutSubtreeIfNeeded()

        // The columns the picture's colour is drawn in.
        let drawn = try XCTUnwrap(button.bitmapImageRepForCachingDisplay(in: button.bounds))
        button.cacheDisplay(in: button.bounds, to: drawn)
        let columns = (0..<drawn.pixelsWide).filter { x in
            (0..<drawn.pixelsHigh).contains { y in
                guard let colour = drawn.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { return false }
                return colour.blueComponent > 0.45 && colour.blueComponent - colour.redComponent > 0.2
                    && colour.alphaComponent > 0.9
            }
        }
        let scale = CGFloat(drawn.pixelsWide) / button.bounds.width
        let width = CGFloat((columns.last ?? 0) - (columns.first ?? 0) + 1) / scale

        XCTAssertFalse(columns.isEmpty, "the picture is drawn")
        XCTAssertEqual(width, 40, accuracy: 1.5, "as wide as the room inside the padding")
    }

    /// A button standing taller than AppKit's push button stands as tall as it is placed - its bezel the flexible
    /// push button's - and one of the push button's height keeps the push button's bezel.
    @MainActor
    func testATallButtonsBezelIsAsTallAsTheButton() throws {
        let renderer = AppKitRenderer.running {
            VStack {
                Button(icon: ImageSource("save.png")).width(48).height(48).padding(10)
                Button("Save")
            }
            .horizontalAlignment(.start)
            .verticalAlignment(.start)
        }
        defer { renderer.closeForTesting() }
        renderer.windowsForTesting.first?.window?.contentView?.layoutSubtreeIfNeeded()
        let buttons = renderer.nativeViews(AppKitButtonView.self)

        XCTAssertEqual(buttons.map(\.bezelStyle), [.flexiblePush, .push])
    }

    /// A destructive action's words stand in the system's red where the tree colours them not, the main action is
    /// AppKit's accent, and a colour the tree states wins over the role's.
    @MainActor
    func testARoleDrawsAsAppKitDrawsIt() throws {
        let renderer = AppKitRenderer.running {
            VStack {
                Button("Delete").role(.destructive)
                Button("Save").role(.primary)
                Button("Erase").role(.destructive).textColor(.blue)
                Button("Plain")
            }
        }
        defer { renderer.closeForTesting() }
        let buttons = renderer.nativeViews(AppKitButtonView.self)
        let words = buttons.map { $0.attributedTitle.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor }

        XCTAssertEqual(words[0], .systemRed, "a destructive action's words")
        XCTAssertEqual(buttons[1].bezelColor, .controlAccentColor, "the main action's accent")
        XCTAssertNotEqual(words[2], .systemRed, "the tree's colour wins")
        XCTAssertEqual(words[3], .controlTextColor)
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
        func icon(_ aspect: ContentMode) -> [Prop: HostValue] {
            [.icon: .string("save.png"), .contentMode: .enumeration(aspect.rawValue)]
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

    /// A button whose click opens its menu wears its box - AppKit's own menu buttons take none - and an arrow
    /// pointing down just after its words, inside the room it keeps; it is a menu button to assistive technology.
    @MainActor
    func testAButtonOpeningAMenuWearsItsBoxAndAnArrowDown() throws {
        let renderer = AppKitRenderer.running {
            HStack {
                Button("Share").menu {
                    MenuItem("Mail")
                    MenuItem("Message")
                }
                .background(Color("#8E6BF0")).textColor(Color("#FFFFFF")).shape(.capsule)
                .padding(horizontal: 16, vertical: 8)
            }
        }
        defer { renderer.closeForTesting() }
        let button = try XCTUnwrap(renderer.nativeViews(AppKitButtonView.self).first)
        button.frame = NSRect(origin: .zero, size: button.fittingSize)
        button.layoutSubtreeIfNeeded()

        XCTAssertEqual(button.opening, .click)
        XCTAssertEqual(button.offeredItems.map(\.title), ["Mail", "Message"])
        XCTAssertNotNil(button.layer?.backgroundColor, "its box")
        XCTAssertTrue(button.showsMenuMark)
        let mark = try XCTUnwrap(button.subviews.first { $0 is NSImageView })
        let cell = try XCTUnwrap(button.cell)
        let words = cell.titleRect(forBounds: button.bounds)
        let wordsEnd = words.midX + button.attributedTitle.size().width / 2
        XCTAssertGreaterThanOrEqual(mark.frame.minX, wordsEnd, "after the words: \(mark.frame), \(words)")
        XCTAssertLessThanOrEqual(mark.frame.maxX, button.bounds.maxX - 8, "inside the padding: \(mark.frame)")
        XCTAssertEqual(cell.accessibilityRole(), .menuButton)
    }

    /// A split button's click is its own; its arrow is a part of its own at its trailing edge, set off by a line, a
    /// menu button to assistive technology, its words clear of it.
    @MainActor
    func testASplitButtonsArrowIsAPartOfItsOwn() throws {
        let heard = Received<String>()
        let renderer = AppKitRenderer.running {
            HStack {
                Button("Save").onClicked { heard.values.append("save") }.menu {
                    MenuItem("Save as")
                    MenuItem("Save a copy")
                }
            }
        }
        defer { renderer.closeForTesting() }
        let button = try XCTUnwrap(renderer.nativeViews(AppKitButtonView.self).first)
        button.frame = NSRect(origin: .zero, size: button.fittingSize)
        button.layoutSubtreeIfNeeded()

        XCTAssertEqual(button.offeredItems.map(\.title), ["Save as", "Save a copy"])
        XCTAssertFalse(button.showsMenuMark)
        let part = try XCTUnwrap(button.subviews.compactMap { $0 as? NSButton }.first)
        XCTAssertEqual(part.frame.maxX, button.bounds.maxX, accuracy: 0.5)
        XCTAssertEqual(part.frame.height, button.bounds.height, accuracy: 0.5)
        XCTAssertEqual(part.cell?.accessibilityRole(), .menuButton)
        let words = try XCTUnwrap(button.cell).titleRect(forBounds: button.bounds)
        XCTAssertLessThanOrEqual(words.midX + button.attributedTitle.size().width / 2, part.frame.minX)

        button.performClick(nil)
        XCTAssertEqual(heard.values, ["save"], "the click its own")
    }

    /// A split button draws its words in the middle of the room before its arrow part, styled or AppKit's own.
    @MainActor
    func testASplitButtonsWordsStandInTheMiddleBeforeItsArrow() throws {
        let renderer = AppKitRenderer.running {
            VStack {
                Button("Save").onClicked {}.menu { MenuItem("Save as") }
                    .background(Color("#8E6BF0")).textColor(Color("#FF0000")).shape(.capsule)
                    .padding(horizontal: 16, vertical: 8)
                Button("Save").onClicked {}.menu { MenuItem("Save as") }.textColor(Color("#FF0000"))
            }
        }
        defer { renderer.closeForTesting() }
        for button in renderer.nativeViews(AppKitButtonView.self) {
            button.frame = NSRect(origin: .zero, size: button.fittingSize)
            button.layoutSubtreeIfNeeded()
            let room = button.bounds.width - AppKitButtonArrow.partWidth

            // The columns before the arrow part where the red words are drawn.
            let drawn = try XCTUnwrap(button.bitmapImageRepForCachingDisplay(in: button.bounds))
            button.cacheDisplay(in: button.bounds, to: drawn)
            let scale = CGFloat(drawn.pixelsWide) / button.bounds.width
            let columns = (0..<Int(room * scale)).filter { x in
                (0..<drawn.pixelsHigh).contains { y in
                    guard let colour = drawn.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return false }
                    return colour.alphaComponent > 0.5 && colour.redComponent > 0.7 && colour.greenComponent < 0.3
                        && colour.blueComponent < 0.3
                }
            }
            let first = CGFloat(try XCTUnwrap(columns.first)) / scale
            let last = CGFloat(try XCTUnwrap(columns.last)) / scale
            XCTAssertEqual(
                first, room - last, accuracy: 2,
                "\(button.isBordered ? "bordered" : "styled"): the words from \(first) to \(last) in \(room)")
        }
    }

    /// A held button's click is its own and it shows no arrow; assistive technology asking for its menu opens it.
    @MainActor
    func testAHeldButtonsClickIsItsOwnItsMenuAsked() throws {
        let heard = Received<String>()
        let renderer = AppKitRenderer.running {
            HStack {
                Button("Open").onClicked { heard.values.append("open") }.menu(.held) { MenuItem("Report.txt") }
            }
        }
        defer { renderer.closeForTesting() }
        let button = try XCTUnwrap(renderer.nativeViews(AppKitButtonView.self).first)

        XCTAssertTrue(button.subviews.isEmpty, "no arrow")
        button.performClick(nil)
        XCTAssertEqual(heard.values, ["open"])

        let watch = MenuWatch()
        defer { watch.stop() }
        XCTAssertTrue(try XCTUnwrap(button.cell).accessibilityPerformShowMenu())
        XCTAssertEqual(watch.opened, ["Report.txt"], "its menu opened")
    }

    /// An icon alone in a button stands at its own size, smaller where the button is: an icon is never stretched
    /// over the room a picture would fill.
    @MainActor
    func testAnIconAloneIsNeverDrawnLarger() throws {
        let renderer = AppKitRenderer.running {
            HStack { Button(icon: .icon(.settings)).accessibilityLabel("Settings") }
        }
        defer { renderer.closeForTesting() }
        let button = try XCTUnwrap(renderer.nativeViews(AppKitButtonView.self).first)
        button.frame = NSRect(x: 0, y: 0, width: 60, height: 60)

        let image = try XCTUnwrap(button.image)
        let drawn = try XCTUnwrap(button.cell as? NSButtonCell).imageRect(forBounds: button.bounds)
        XCTAssertLessThanOrEqual(drawn.height, image.size.height + 0.5, "\(drawn) for \(image.size)")
    }

    /// A button's icon is drawn in its words' colour: the platform's, a destructive role's red, the tree's own.
    @MainActor
    func testAButtonsIconIsDrawnInItsWordsColour() throws {
        let renderer = AppKitRenderer.running {
            VStack {
                Button("Share").icon(.icon(.share))
                Button("Delete").icon(.icon(.delete)).role(.destructive)
                Button("Mail").icon(.icon(.mail)).textColor(.blue)
            }
            .horizontalAlignment(.start)
            .verticalAlignment(.start)
        }
        defer { renderer.closeForTesting() }
        renderer.windowsForTesting.first?.window?.contentView?.layoutSubtreeIfNeeded()

        for button in renderer.nativeViews(AppKitButtonView.self) {
            let cell = try XCTUnwrap(button.cell as? NSButtonCell)
            let (image, title) = (cell.imageRect(forBounds: button.bounds), cell.titleRect(forBounds: button.bounds))
            let icon = try inkColour(of: button, columns: image.minX...image.maxX)
            let words = try inkColour(of: button, columns: title.minX...title.maxX)

            XCTAssertTrue(sameInk(icon, words), "\(button.title): the icon's \(String(describing: icon)), the words' \(String(describing: words))")
        }
    }

    /// An icon beside its button's words stands at its own size, smaller where the button is: a tall button does
    /// not stretch it over the words.
    @MainActor
    func testAnIconBesideWordsIsNeverDrawnLarger() throws {
        let renderer = AppKitRenderer.running {
            HStack { Button("Share").icon(.icon(.share)) }
        }
        defer { renderer.closeForTesting() }
        let button = try XCTUnwrap(renderer.nativeViews(AppKitButtonView.self).first)
        button.frame = NSRect(x: 0, y: 0, width: 160, height: 60)

        let image = try XCTUnwrap(button.image)
        let drawn = try XCTUnwrap(button.cell as? NSButtonCell).imageRect(forBounds: button.bounds)
        XCTAssertGreaterThan(button.bounds.height, image.size.height * 2, "\(button.bounds)")
        XCTAssertLessThanOrEqual(drawn.height, image.size.height + 0.5, "\(drawn) for \(image.size)")
    }
}

/// A menu as it opens: its entries read, and closed at once as the run loop tracks it.
@MainActor
private final class MenuWatch: NSObject {
    private(set) var opened: [String] = []

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self, selector: #selector(began(_:)), name: NSMenu.didBeginTrackingNotification, object: nil)
    }

    @objc private func began(_ note: Notification) {
        guard let menu = note.object as? NSMenu else { return }
        opened = menu.items.map(\.title)
        menu.perform(#selector(NSMenu.cancelTracking), with: nil, afterDelay: 0, inModes: [.eventTracking])
    }

    func stop() {
        NotificationCenter.default.removeObserver(self)
    }
}

#endif
