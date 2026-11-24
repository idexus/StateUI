// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import XCTest

/// A layout's children travel to the places a patch gives them, under the
/// layout's motion, and follow a room that moves with no patch behind it.
@MainActor
final class AppKitLayoutMotionTests: XCTestCase {
    /// A vertical stack of 100-wide boxes, 40 tall unless `heights` says
    /// otherwise, in `order`.
    private func stack(
        _ order: [String],
        motion: Motion? = .eased(.milliseconds(200), curve: .linear),
        heights: [String: Double] = [:],
        watched: String? = nil
    ) -> HostPatch {
        var stack = HostPatch(id: .manual("stack"), type: .vStack)
        if let motion { stack.motion = HostLayoutMotion(motion: motion, lanes: .all) }
        stack.children = .arranged(order.map { name in
            var box = HostPatch(id: .manual(name), type: .rectangle)
            box.properties[VisualElementContract.width.token] = .number(100)
            box.properties[VisualElementContract.height.token] = .number(heights[name] ?? 40)
            if name == watched { box.events = .replace([.layoutFrameChanged: 7]) }
            return box
        })
        return stack
    }

    /// A label whose width travels lays its words out at the width it is bound
    /// for: midway, its view is already as wide as it lands, so words that fit
    /// there on one line never break at the widths its place passes through.
    @MainActor
    func testATextsWordsStandAtTheWidthItTravelsTo() throws {
        var now = 0.0
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.finish() }

        func caption(_ text: String) -> HostPatch {
            var stack = HostPatch(id: .manual("stack"), type: .vStack)
            stack.motion = HostLayoutMotion(motion: .eased(.milliseconds(200), curve: .linear), lanes: .all)
            var label = HostPatch(id: .manual("caption"), type: .text)
            label.properties = [.text: .string(text), .horizontalAlignment: .enumeration(Alignment.start.rawValue)]
            stack.children = .arranged([label])
            return stack
        }
        renderer.applyForTesting(caption("Text"))
        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("stack")))
        let label = try XCTUnwrap(renderer.viewForTesting(id: .manual("caption")))
        native.frame = NSRect(x: 0, y: 0, width: 300, height: 200)
        native.layoutSubtreeIfNeeded()
        let start = label.frame.width

        renderer.applyForTesting(caption("Text & typing"))
        native.layoutSubtreeIfNeeded()
        now = 100
        renderer.advanceAnimationsForTesting()
        native.layoutSubtreeIfNeeded()
        let midway = label.frame.width
        now = 200
        renderer.advanceAnimationsForTesting()
        native.layoutSubtreeIfNeeded()

        XCTAssertGreaterThan(label.frame.width, start + 1, "the caption grew")
        XCTAssertEqual(midway, label.frame.width, accuracy: 0.5, "its words at the width it is bound for")
    }

    /// A button whose room widens around words that already fit grows its box the whole way - a button taking a
    /// wider cell, midway between the width it stood at and the one it lands at.
    @MainActor
    func testAButtonTakingAWiderRoomGrowsTheWholeWay() throws {
        var now = 0.0
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.finish() }

        func row(filling: Bool) -> HostPatch {
            var stack = HostPatch(id: .manual("stack"), type: .vStack)
            stack.motion = HostLayoutMotion(motion: .eased(.milliseconds(200), curve: .linear), lanes: .all)
            var button = HostPatch(id: .manual("details"), type: .button)
            let alignment = filling ? Alignment.fill : Alignment.center
            button.properties = [.text: .string("Details"), .horizontalAlignment: .enumeration(alignment.rawValue)]
            stack.children = .arranged([button])
            return stack
        }
        renderer.applyForTesting(row(filling: false))
        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("stack")))
        let button = try XCTUnwrap(renderer.viewForTesting(id: .manual("details")))
        native.frame = NSRect(x: 0, y: 0, width: 300, height: 200)
        native.layoutSubtreeIfNeeded()
        let start = button.frame.width

        renderer.applyForTesting(row(filling: true))
        native.layoutSubtreeIfNeeded()
        now = 100
        renderer.advanceAnimationsForTesting()
        native.layoutSubtreeIfNeeded()
        let midway = button.frame.width
        now = 200
        renderer.advanceAnimationsForTesting()
        native.layoutSubtreeIfNeeded()

        XCTAssertEqual(button.frame.width, 300, accuracy: 0.5, "it lands filling the stack")
        XCTAssertEqual(midway, (start + 300) / 2, accuracy: 1, "halfway, its box halfway: started at \(start)")
    }

    /// A button whose new words need more than its box keeps showing its former words while the box grows, and
    /// shows the new ones as it lands.
    @MainActor
    func testAButtonsGrownWordsShowOnceItsBoxHoldsThem() throws {
        var now = 0.0
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.finish() }

        func row(_ words: String) -> HostPatch {
            var stack = HostPatch(id: .manual("stack"), type: .vStack)
            stack.motion = HostLayoutMotion(motion: .eased(.milliseconds(200), curve: .linear), lanes: .all)
            var button = HostPatch(id: .manual("toggle"), type: .button)
            button.properties = [.text: .string(words), .horizontalAlignment: .enumeration(Alignment.center.rawValue)]
            stack.children = .arranged([button])
            return stack
        }
        renderer.applyForTesting(row("On"))
        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("stack")))
        let button = try XCTUnwrap(renderer.viewForTesting(id: .manual("toggle")) as? NSButton)
        native.frame = NSRect(x: 0, y: 0, width: 300, height: 200)
        native.layoutSubtreeIfNeeded()
        let start = button.frame.width

        renderer.applyForTesting(row("Switched off"))
        native.layoutSubtreeIfNeeded()
        now = 100
        renderer.advanceAnimationsForTesting()
        native.layoutSubtreeIfNeeded()
        let (midway, saidMidway) = (button.frame.width, button.title)
        now = 200
        renderer.advanceAnimationsForTesting()
        native.layoutSubtreeIfNeeded()

        XCTAssertEqual(saidMidway, "On", "midway, its former words")
        XCTAssertEqual(midway, (start + button.frame.width) / 2, accuracy: 1, "in a box halfway grown")
        XCTAssertEqual(button.title, "Switched off", "and the new ones as it lands")
        XCTAssertGreaterThan(button.frame.width, start + 10)
    }

    /// A label filling a stack whose width travels lays its words out at the width the stack is bound for: the
    /// stack lays its children out there, its own place traveling around them.
    @MainActor
    func testALabelInAStackThatTravelsKeepsItsWordsOnOneLine() throws {
        var now = 0.0
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.finish() }

        func caption(_ text: String) -> HostPatch {
            var outer = HostPatch(id: .manual("outer"), type: .vStack)
            outer.motion = HostLayoutMotion(motion: .eased(.milliseconds(200), curve: .linear), lanes: .all)
            var stack = HostPatch(id: .manual("stack"), type: .vStack)
            stack.properties = [.horizontalAlignment: .enumeration(Alignment.start.rawValue)]
            var label = HostPatch(id: .manual("caption"), type: .text)
            label.properties = [.text: .string(text)]
            stack.children = .arranged([label])
            outer.children = .arranged([stack])
            return outer
        }
        renderer.applyForTesting(caption("The popover shows"))
        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("outer")))
        let label = try XCTUnwrap(renderer.viewForTesting(id: .manual("caption")))
        native.frame = NSRect(x: 0, y: 0, width: 300, height: 200)
        native.layoutSubtreeIfNeeded()
        let line = label.frame.height

        renderer.applyForTesting(caption("The popover is closed"))
        native.layoutSubtreeIfNeeded()
        var heights = [label.frame.height]
        for step in 1...4 {
            now = Double(step) * 50
            renderer.advanceAnimationsForTesting()
            native.layoutSubtreeIfNeeded()
            heights.append(label.frame.height)
        }

        XCTAssertEqual(heights.max() ?? 0, line, accuracy: 0.5, "one line all the way: \(heights)")
    }

    /// A child a patch moves starts from where it stood, travels on the
    /// layout's law, and lands exactly on its new place.
    @MainActor
    func testAChildAPatchMovesTravelsToItsNewPlace() throws {
        var now = 0.0
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.finish() }

        renderer.applyForTesting(stack(["a", "b"]))
        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("stack")))
        let moved = try XCTUnwrap(renderer.viewForTesting(id: .manual("b")))
        native.frame = NSRect(x: 0, y: 0, width: 300, height: 200)
        native.layoutSubtreeIfNeeded()
        XCTAssertEqual(moved.frame.minY, 40, accuracy: 0.001, "the first arrangement is an arrival")

        renderer.applyForTesting(stack(["b", "a"]))
        native.layoutSubtreeIfNeeded()
        XCTAssertEqual(moved.frame.minY, 40, accuracy: 0.001, "a child starts from where it stood")

        now = 100
        renderer.advanceAnimationsForTesting()
        native.layoutSubtreeIfNeeded()
        XCTAssertEqual(moved.frame.minY, 20, accuracy: 0.001, "halfway through a linear 200 ms animation")

        now = 200
        renderer.advanceAnimationsForTesting()
        native.layoutSubtreeIfNeeded()
        XCTAssertEqual(moved.frame.minY, 0, accuracy: 0.001, "and it lands exactly")
        XCTAssertFalse(renderer.animatingForTesting)
    }

    /// A room that resizes with no patch behind it holds nothing different:
    /// its children follow it exactly, because a child that glides after the
    /// user's own hand is late every frame.
    @MainActor
    func testARoomThatResizesSnapsItsChildren() throws {
        var now = 0.0
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.finish() }

        var layout = HostPatch(id: .manual("layout"), type: .zStack)
        layout.motion = HostLayoutMotion(motion: .eased(.milliseconds(200), curve: .linear), lanes: .all)
        var box = HostPatch(id: .manual("box"), type: .rectangle)
        box.properties[VisualElementContract.width.token] = .number(50)
        box.properties[VisualElementContract.height.token] = .number(50)
        box.properties[.horizontalAlignment] = .enumeration(Alignment.end.rawValue)
        layout.children = .arranged([box])

        renderer.applyForTesting(layout)
        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("layout")))
        let moved = try XCTUnwrap(renderer.viewForTesting(id: .manual("box")))
        native.frame = NSRect(x: 0, y: 0, width: 200, height: 100)
        native.layoutSubtreeIfNeeded()
        XCTAssertEqual(moved.frame.minX, 150, accuracy: 0.001)

        now = 50
        native.frame = NSRect(x: 0, y: 0, width: 400, height: 100)
        native.layoutSubtreeIfNeeded()

        XCTAssertEqual(moved.frame.minX, 350, accuracy: 0.001, "the child follows the room exactly")
        XCTAssertFalse(renderer.animatingForTesting, "a resize starts no animation")
    }

    /// A child that joins a standing layout fades in under the layout's law;
    /// the children of a first arrangement are simply there.
    @MainActor
    func testAChildThatJoinsAStandingLayoutFadesIn() throws {
        var now = 0.0
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.finish() }

        renderer.applyForTesting(stack(["a"]))
        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("stack")))
        native.frame = NSRect(x: 0, y: 0, width: 300, height: 200)
        native.layoutSubtreeIfNeeded()
        let first = try XCTUnwrap(renderer.viewForTesting(id: .manual("a")))
        XCTAssertEqual(first.alphaValue, 1, accuracy: 0.001, "a first arrangement does not fade")

        renderer.applyForTesting(stack(["a", "b"]))
        native.layoutSubtreeIfNeeded()
        let joined = try XCTUnwrap(renderer.viewForTesting(id: .manual("b")))
        XCTAssertEqual(joined.alphaValue, 0, accuracy: 0.001, "it starts unseen")

        now = 100
        renderer.advanceAnimationsForTesting()
        XCTAssertEqual(joined.alphaValue, 0.5, accuracy: 0.001, "halfway on a linear 200 ms fade")

        now = 200
        renderer.advanceAnimationsForTesting()
        XCTAssertEqual(joined.alphaValue, 1, accuracy: 0.001)
        XCTAssertFalse(renderer.animatingForTesting)
    }

    /// A row leaving a standing stack by its exit stays drawn where it stood - a subview still, deaf to input,
    /// fading and moving as its effect says - while the row under it closes over its place at once; as the exit
    /// lands it is gone.
    @MainActor
    func testARowLeavingByItsExitIsDrawnUntilItLands() throws {
        var now = 0.0
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.finish() }
        let leaving = Transition(enter: .identity, exit: .opacity.combined(with: .translation(x: 40)))
        let law = HostLayoutMotion(motion: .eased(.milliseconds(200), curve: .linear), lanes: .all)
        func rows(_ order: [String]) -> HostPatch {
            var stack = HostPatch(id: .manual("stack"), type: .vStack)
            stack.motion = law
            stack.children = .arranged(order.map { name in
                var box = HostPatch(id: .manual(name), type: .rectangle)
                box.properties[VisualElementContract.width.token] = .number(100)
                box.properties[VisualElementContract.height.token] = .number(40)
                if name == "b" {
                    box.properties[.transition] = leaving.propValue
                    box.motion = law
                }
                return box
            })
            return stack
        }

        renderer.applyForTesting(rows(["a", "b", "c"]))
        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("stack")))
        native.frame = NSRect(x: 0, y: 0, width: 300, height: 200)
        native.layoutSubtreeIfNeeded()
        let b = try XCTUnwrap(renderer.viewForTesting(id: .manual("b")))
        let c = try XCTUnwrap(renderer.viewForTesting(id: .manual("c")))
        let (stood, below) = (b.frame, c.frame)

        renderer.applyForTesting(rows(["a", "c"]))
        native.layoutSubtreeIfNeeded()
        XCTAssertTrue(b.superview === native, "still drawn in its stack")
        XCTAssertEqual(b.frame, stood, "where it stood")
        XCTAssertEqual(native.hitTest(NSPoint(x: stood.midX, y: stood.midY)) === b, false, "and deaf to a press")
        XCTAssertEqual(native.subviews.filter { $0 === b || $0 === c }.count, 2)

        now = 100
        renderer.advanceAnimationsForTesting()
        native.layoutSubtreeIfNeeded()
        XCTAssertEqual(b.alphaValue, 0.5, accuracy: 0.001, "half way out")
        XCTAssertEqual(b.frame, stood, "no layout places it any more")
        XCTAssertEqual(c.frame.minY, (below.minY + stood.minY) / 2, accuracy: 0.001, "the row under it closes meanwhile")

        now = 200
        renderer.advanceAnimationsForTesting()
        native.layoutSubtreeIfNeeded()
        XCTAssertNil(b.superview, "gone as its exit lands")
        XCTAssertEqual(c.frame, stood, "and the row under it stands in its place")
        XCTAssertFalse(renderer.animatingForTesting)
    }

    /// A view entering by a move is drawn where it sets out in the very layout pass that gives it its first
    /// place - before any display frame - never one frame whole at its place first.
    @MainActor
    func testAViewEnteringByAMoveIsDrawnWhereItSetsOutFromItsFirstPass() throws {
        let renderer = testRenderer(
            resourceDirectory: nil, presentsWindows: false, clock: { 0 }, reducesMotion: { false })
        defer { renderer.finish() }
        let law = HostLayoutMotion(motion: .eased(.milliseconds(200), curve: .linear), lanes: .all)
        let entering = Transition(enter: .translation(y: 40), exit: .identity)
        func rows(_ order: [String]) -> HostPatch {
            var stack = HostPatch(id: .manual("stack"), type: .vStack)
            stack.motion = law
            stack.children = .arranged(order.map { name in
                var box = HostPatch(id: .manual(name), type: .rectangle)
                box.properties[VisualElementContract.width.token] = .number(100)
                box.properties[VisualElementContract.height.token] = .number(40)
                if name == "b" {
                    box.properties[.transition] = entering.propValue
                    box.motion = law
                }
                return box
            })
            return stack
        }

        renderer.applyForTesting(rows(["a"]))
        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("stack")))
        native.frame = NSRect(x: 0, y: 0, width: 300, height: 200)
        native.layoutSubtreeIfNeeded()

        renderer.applyForTesting(rows(["a", "b"]))
        native.layoutSubtreeIfNeeded()
        let b = try XCTUnwrap(renderer.viewForTesting(id: .manual("b")))
        XCTAssertEqual(try XCTUnwrap(b.layer).transform.m42, 40, accuracy: 0.001, "where it sets out, at once")
    }

    /// A thumbnail coming back from its picture - made in a row the same patch makes, under an application that
    /// moves - is set out over the picture's rectangle from the layout pass that places it, the row unfaded; the
    /// picture, kept by its ZStack, stands drawn whole where it was and in front of the row, the larger of the two -
    /// it alone crosses over, late - and the thumbnail stands whole under it.
    @MainActor
    func testAThumbnailComingBackSetsOutUnderItsPictureFromItsFirstPass() throws {
        let renderer = testRenderer(
            resourceDirectory: nil, presentsWindows: false, clock: { 0 }, reducesMotion: { false })
        defer { renderer.finish() }
        renderer.runtime.layoutMotion.applicationMotion = .eased(.milliseconds(200), curve: .linear)
        let law = HostLayoutMotion(motion: .eased(.milliseconds(700), curve: .linear), lanes: .all)
        func keyed(_ id: String, _ key: Int, width: Double?, height: Double) -> HostPatch {
            var box = HostPatch(id: .manual(id), type: .rectangle)
            box.properties[.transitionID] = .number(Double(key))
            if let width { box.properties[VisualElementContract.width.token] = .number(width) }
            box.properties[VisualElementContract.height.token] = .number(height)
            box.motion = law
            return box
        }
        func scope(_ children: [HostPatch]) -> HostPatch {
            var scope = HostPatch(id: .manual("scope"), type: .zStack)
            scope.children = .arranged(children)
            return scope
        }
        var row = HostPatch(id: .manual("row"), type: .hStack)
        row.properties[.horizontalAlignment] = .enumeration(Alignment.start.rawValue)
        row.properties[.verticalAlignment] = .enumeration(Alignment.start.rawValue)
        row.children = .arranged((0..<3).map { keyed("thumbnail\($0)", $0, width: 56, height: 40) })

        renderer.applyForTesting(scope([keyed("picture", 1, width: nil, height: 150)]))
        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("scope")))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 150), styleMask: .borderless, backing: .buffered,
            defer: false)
        window.contentView?.addSubview(native)
        native.frame = NSRect(x: 0, y: 0, width: 300, height: 150)
        native.layoutSubtreeIfNeeded()
        // Frames pass before the picture is pressed: the scope is no layout its patch made any more.
        for _ in 0..<3 { renderer.runtime.displayCycle.frame(now: 0) }

        renderer.applyForTesting(scope([row]))
        native.layoutSubtreeIfNeeded()
        let thumbnail = try XCTUnwrap(renderer.viewForTesting(id: .manual("thumbnail1")))
        let layer = try XCTUnwrap(thumbnail.layer)
        XCTAssertEqual(layer.transform.m11, 300.0 / 56, accuracy: 0.01, "as wide as the picture, at once")
        XCTAssertEqual(layer.transform.m22, 150.0 / 40, accuracy: 0.01, "as tall as the picture, at once")
        var shown: NSView? = thumbnail.superview
        while let view = shown, view !== native {
            XCTAssertFalse(view.isHidden, "\(view) hidden")
            XCTAssertEqual(view.alphaValue, 1, accuracy: 0.001, "\(view) faded")
            shown = view.superview
        }
        XCTAssertEqual(thumbnail.alphaValue, 1, accuracy: 0.001, "behind the picture, whole")
        let kept = renderer.runtime.tree.root?.keptExits.first { $0.id == .manual("picture") }
        let picture = try XCTUnwrap((kept?.native as? AppKitElement)?.view)
        XCTAssertTrue(picture.superview === native, "the picture kept as it goes along")
        XCTAssertEqual(picture.alphaValue, 1, accuracy: 0.001, "drawn whole as it sets out")
        let thumbnails = try XCTUnwrap(renderer.viewForTesting(id: .manual("row")))
        let drawn = native.subviews.filter { $0 === thumbnails || $0 === picture }
        XCTAssertEqual(drawn, [thumbnails, picture], "the picture in front")
    }

    /// A CARD COMING BACK FROM ITS DETAIL INTO THE DECK A MOTION LAYOUT PLACES SETS OUT FROM THE DETAIL: the deck's
    /// first pass asks its program, so the card is first placed in its holder - sixty by eighty - never across the
    /// deck's room, and is drawn as large as the detail as it sets out.
    @MainActor
    func testACardComingBackIntoItsDeckSetsOutFromItsDetail() throws {
        let opened = State(wrappedValue: true)
        let way = Motion.eased(.milliseconds(600), curve: .linear)
        let renderer = AppKitRenderer.running {
            VStack {
                if opened.wrappedValue {
                    Rectangle().id(5).transitionID(5).height(200).motion(way)
                } else {
                    MotionLayout([5, 6], parameters: State(wrappedValue: 0.0).projectedValue) { card in
                        Rectangle().id(card).transitionID(card).motion(way)
                    } placements: { _, _ in
                        [Placement(Rect(x: 40, y: 40, width: 60, height: 80)),
                         Placement(Rect(x: 110, y: 40, width: 60, height: 80), transform: .scale(0.8))]
                    }
                    .height(200)
                }
            }
        }
        defer { renderer.finish() }
        let content = try XCTUnwrap(renderer.windowsForTesting.first?.window?.contentView)
        content.layoutSubtreeIfNeeded()
        for _ in 0..<3 { renderer.runtime.displayCycle.frame(now: 0) }
        let detail = try XCTUnwrap(renderer.runtime.tree.root?.first(type: .rectangle))
        let width = try XCTUnwrap((detail.native as? AppKitElement)?.view).frame.width

        opened.wrappedValue = false
        renderer.runtime.pump.turn()
        content.layoutSubtreeIfNeeded()
        let deck = try XCTUnwrap(renderer.runtime.tree.root?.first(type: .motionLayout))
        let card = try XCTUnwrap(deck.children.first?.children.first)
        let view = try XCTUnwrap((card.native as? AppKitElement)?.view)
        XCTAssertEqual(view.frame.size, NSSize(width: 60, height: 80), "first placed in its holder")
        let layer = try XCTUnwrap(view.layer)
        XCTAssertEqual(layer.transform.m22, 200.0 / 80, accuracy: 0.01, "as tall as the detail as it sets out")
        XCTAssertEqual(layer.transform.m11, width / 60, accuracy: 0.01, "as wide as the detail as it sets out")
    }

    /// A view leaving out of its room, in a stack narrower than the scroller showing it, goes wholly past the
    /// scroller's edge - the stack draws beyond its own room - as AppKit lays both out.
    @MainActor
    func testAViewLeavingOutOfItsRoomGoesPastTheScrollerShowingIt() throws {
        let renderer = testRenderer(
            resourceDirectory: nil, presentsWindows: false, clock: { 0 }, reducesMotion: { false })
        defer { renderer.finish() }
        let law = HostLayoutMotion(motion: .eased(.milliseconds(200), curve: .linear), lanes: .all)
        func scroller(_ notes: [String]) -> HostPatch {
            var stack = HostPatch(id: .manual("stack"), type: .vStack)
            stack.properties[VisualElementContract.width.token] = .number(200)
            stack.motion = law
            stack.children = .arranged(notes.map { name in
                var note = HostPatch(id: .manual(name), type: .rectangle)
                note.properties[VisualElementContract.width.token] = .number(100)
                note.properties[VisualElementContract.height.token] = .number(40)
                note.properties[.transition] = Transition(enter: .identity, exit: .outside(.right)).propValue
                note.motion = law
                return note
            })
            var scroll = HostPatch(id: .manual("scroll"), type: .scrollView)
            scroll.children = .arranged([stack])
            return scroll
        }

        renderer.applyForTesting(scroller(["note"]))
        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("scroll")))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200), styleMask: .borderless, backing: .buffered,
            defer: false)
        window.contentView?.addSubview(native)
        native.frame = NSRect(x: 0, y: 0, width: 300, height: 200)
        native.layoutSubtreeIfNeeded()
        let view = try XCTUnwrap(renderer.viewForTesting(id: .manual("note")))
        let across = view.convert(view.bounds, to: native).minX
        let stack = try XCTUnwrap(renderer.viewForTesting(id: .manual("stack")))
        XCTAssertLessThan(stack.frame.width, 300, "the stack is narrower than its scroller")
        let note = try XCTUnwrap(renderer.runtime.tree.root?.first(id: .manual("note")))

        renderer.applyForTesting(scroller([]))
        XCTAssertEqual(note.lifecycle, .exiting)
        XCTAssertEqual(note.exitEnds[.translationX] ?? .nan, 300 - across, accuracy: 0.5, "past the scroller's edge")
    }

    /// Where the user asks for less movement, every child arrives and none
    /// fades in.
    @MainActor
    func testUnderReducedMotionEveryChildArrives() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { 0 },
            reducesMotion: { true })
        defer { renderer.finish() }

        renderer.applyForTesting(stack(["a", "b"]))
        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("stack")))
        let moved = try XCTUnwrap(renderer.viewForTesting(id: .manual("b")))
        native.frame = NSRect(x: 0, y: 0, width: 300, height: 200)
        native.layoutSubtreeIfNeeded()

        renderer.applyForTesting(stack(["b", "a", "c"]))
        native.layoutSubtreeIfNeeded()
        let joined = try XCTUnwrap(renderer.viewForTesting(id: .manual("c")))

        XCTAssertEqual(moved.frame.minY, 0, accuracy: 0.001)
        XCTAssertEqual(joined.alphaValue, 1, accuracy: 0.001)
        XCTAssertFalse(renderer.animatingForTesting)
    }
}
#endif
