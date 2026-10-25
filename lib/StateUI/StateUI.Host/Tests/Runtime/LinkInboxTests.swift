// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// A link the application is asked to open, given to one window by one rule on every host, and held until a window
/// that hears links stands.
@MainActor
final class LinkInboxTests: XCTestCase {
    /// A link goes to the window the platform names where it hears links, else to the window activated last that
    /// does, else to the first that does; a window that hears none is never given one.
    func testALinkGoesToTheWindowTheRuleChooses() throws {
        let runtime = Self.windows(["deaf": false, "first": true, "second": true])
        let windows = runtime.tree.root?.windows ?? []
        let (deaf, first, second) = try (Self.window("deaf", runtime), Self.window("first", runtime), Self.window("second", runtime))
        var inbox = LinkInbox()

        inbox.opened("notes://1", in: second)
        XCTAssertEqual(Self.names(inbox.deliver(to: windows, activatedLast: { _ in first })), ["second notes://1"])

        inbox.opened("notes://2", in: deaf)
        XCTAssertEqual(Self.names(inbox.deliver(to: windows, activatedLast: { _ in second })), ["second notes://2"],
                       "the window activated last that hears, where the one named hears none")

        inbox.opened("notes://3", in: nil)
        XCTAssertEqual(Self.names(inbox.deliver(to: windows, activatedLast: { _ in nil })), ["first notes://3"],
                       "the first that hears, where none was activated")
        XCTAssertFalse(inbox.isWaiting)
    }

    /// A link no window can hear yet waits, in order with any after it, until one stands - a start a link made.
    func testALinkWaitsForAWindowThatHearsIt() throws {
        let runtime = Self.windows(["deaf": false])
        var inbox = LinkInbox()

        inbox.opened("notes://1", in: nil)
        inbox.opened("notes://2", in: nil)
        XCTAssertTrue(inbox.deliver(to: runtime.tree.root?.windows ?? [], activatedLast: { _ in nil }).isEmpty)
        XCTAssertTrue(inbox.isWaiting)

        let later = Self.windows(["deaf": false, "first": true])
        XCTAssertEqual(Self.names(inbox.deliver(to: later.tree.root?.windows ?? [], activatedLast: { _ in nil })),
                       ["first notes://1", "first notes://2"])
    }

    /// On a host: a link opened before the first window stands reaches the window's handler once it does, with
    /// the scene's state; one opened after, at once.
    func testALinkOpenedBeforeTheFirstWindowReachesIt() async throws {
        heard = []
        stateUIUseApp(LinkedApplication())
        let runtime = HostRuntime.still()
        runtime.openLink("notes://note/7")
        XCTAssertEqual(heard, [], "no window yet")

        runtime.connectWindow()
        for _ in 0..<5 {
            runtime.pump.turn()
            await Task.yield()
        }
        XCTAssertEqual(heard, ["notes://note/7"])

        runtime.openLink("notes://note/8")
        for _ in 0..<5 {
            runtime.pump.turn()
            await Task.yield()
        }
        XCTAssertEqual(heard, ["notes://note/7", "notes://note/8"])
    }

    /// An application of one scene whose windows each hear links or not, by name.
    private static func windows(_ hearing: KeyValuePairs<String, Bool>) -> HostRuntime {
        let runtime = HostRuntime.still()
        var root = HostPatch(id: .manual("application"), type: .application)
        var scene = HostPatch(id: .manual("1"), type: .scene)
        scene.children = .arranged(hearing.enumerated().map { place, each in
            var window = HostPatch(id: .manual(each.key), type: .window)
            if each.value { window.events = .replace([.linkOpened: Int32(place + 1)]) }
            return window
        })
        root.children = .arranged([scene])
        runtime.tree.apply(root, complete: true)
        return runtime
    }

    private static func window(_ name: String, _ runtime: HostRuntime) throws -> MountedElement {
        try XCTUnwrap(runtime.tree.root?.first(id: .manual(name)))
    }

    /// Each delivery as "window address".
    private static func names(_ delivered: [(window: MountedElement, address: String)]) -> [String] {
        delivered.map { each in
            guard case .manual(let name) = each.window.id else { return "? \(each.address)" }
            return "\(name) \(each.address)"
        }
    }
}

/// The addresses the linked application's windows heard.
@MainActor private var heard: [String] = []

private struct LinkedApplication: Application {
    var body: some Scene {
        WindowGroup { Text("linked") }
            .onLinkOpened { @MainActor in heard.append($0) }
    }
}
