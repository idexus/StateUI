// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// An element's life in the mounted tree: active, exiting, released. What a view that left tells late - its
/// toolkit's callback already on its way - has no effect, and leaving is two steps each said once.
/// Design: docs/design/host/tree.md#leaving
@MainActor
final class PresentationLifetimeTests: XCTestCase {
    /// A presenter recording the addresses it opened and the elements it handed the keyboard.
    private final class Presenting: HostPresenter {
        var opened: [String] = []
        var focused: [ElementID] = []
        func presentRendered(touchedChrome: Bool) {}
        func presentFrame(movedChrome: Bool) {}
        func perform(_ call: HostActCall) {}
        func open(link address: String) { opened.append(address) }
        func focus(_ element: MountedElement) { focused.append(element.id) }
    }

    /// A stack of a link, a field whose return hands the keyboard on, and the field after it.
    private func mounted(_ runtime: HostRuntime) -> (link: MountedElement, field: MountedElement) {
        var root = HostPatch(id: .manual("root"), type: .vStack)
        var link = HostPatch(id: .manual("link"), type: .link)
        link.properties = [.address: .string("https://www.swift.org"), .text: .string("Swift")]
        var first = HostPatch(id: .manual("first"), type: .textField)
        first.properties = [.submitLabel: SubmitLabel.next.propValue]
        let second = HostPatch(id: .manual("second"), type: .textField)
        root.children = .arranged([link, first, second])
        runtime.tree.apply(root, complete: true)
        return (runtime.tree.root!.first(id: .manual("link"))!, runtime.tree.root!.first(id: .manual("first"))!)
    }

    /// A VIEW THAT LEFT OPENS NO LINK AND MOVES NO FOCUS, though its toolkit tells it a click or a return late: the
    /// host's own answer to either is the element's while it is active, and nobody's after.
    func testAViewThatLeftOpensNoLinkAndMovesNoFocus() {
        let (runtime, presenter) = (HostRuntime.still(), Presenting())
        runtime.presenter = presenter
        let (link, field) = mounted(runtime)

        link.send(.clicked, [], in: runtime)
        field.send(.submitted, [], in: runtime)
        XCTAssertEqual(presenter.opened, ["https://www.swift.org"], "active: its address opens")
        XCTAssertEqual(presenter.focused, [.manual("second")], "and its return hands the keyboard on")

        runtime.tree.root?.leave()
        link.send(.clicked, [], in: runtime)
        field.send(.submitted, [], in: runtime)

        XCTAssertEqual(presenter.opened.count, 1, "left: nothing opens")
        XCTAssertEqual(presenter.focused.count, 1, "and no focus moves")
    }

    /// A VIEW DEACTIVATED HEARS NO INPUT AND REPORTS NOTHING, before its presentation is released: exiting is
    /// already out of the application's reach.
    func testAViewDeactivatedHearsAndReportsNothing() throws {
        let runtime = HostRuntime.still()
        let (link, _) = mounted(runtime)
        let size = LayoutSize(width: 80, height: 20)

        link.deactivate()

        XCTAssertEqual(link.lifecycle, .exiting)
        XCTAssertFalse(link.hear(.press(.began, at: Point(x: 5, y: 5), size: size, byFinger: false), in: runtime))
        XCTAssertFalse(link.hear(.hand(.began, moved: .zero, speed: nil), in: runtime))
        link.reportFrame([0, 0, 80, 20, 0, 0, 0, 0], in: runtime)
        XCTAssertNil(link.laidOutRoom, "a frame it says late is nobody's")
    }

    /// LEAVING IS TWO STEPS, EACH SAID ONCE: the whole subtree is exiting before any of it is let go, a second
    /// deactivation tells a native half nothing more, and a release ends the life of everything under it.
    func testLeavingIsTwoStepsEachSaidOnce() throws {
        let runtime = HostRuntime.still()
        let (link, field) = mounted(runtime)
        let root = try XCTUnwrap(runtime.tree.root)
        let natives = [root, link, field].compactMap { $0.native as? NoView }
        XCTAssertEqual(natives.count, 3)

        root.deactivate()
        XCTAssertEqual([root.lifecycle, link.lifecycle, field.lifecycle], [.exiting, .exiting, .exiting])
        root.deactivate()
        link.deactivate()
        XCTAssertEqual(natives.map(\.deactivated), [1, 1, 1], "once each")

        root.release()
        root.release()
        XCTAssertEqual([root.lifecycle, link.lifecycle, field.lifecycle], [.released, .released, .released])
        XCTAssertEqual(natives.map(\.deactivated), [1, 1, 1])
    }

    /// A VIEW DROPPED FROM ITS PARENT IS RELEASED IN THE SAME TRANSACTION: no exit is kept, so it is deactivated
    /// and released at once.
    func testAViewDroppedIsReleasedAtOnce() throws {
        let runtime = HostRuntime.still()
        let (link, field) = mounted(runtime)

        var root = HostPatch(id: .manual("root"), type: .vStack)
        root.children = .arranged([HostPatch(id: .manual("first"), type: .textField)])
        runtime.tree.apply(root, complete: false)

        XCTAssertEqual(link.lifecycle, .released, "dropped: its life over")
        XCTAssertEqual(field.lifecycle, .active, "kept: as it was")
    }
}
