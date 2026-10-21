// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// The pull to refresh as every host offers and reports it.
@MainActor
final class RefreshPullTests: XCTestCase {
    /// The pull is offered where the element hears it - a handler, or a state the pull writes into - unless it says
    /// otherwise, and not where it hears nothing.
    func testThePullIsOfferedWhereItIsHeard() throws {
        var handled = HostPatch(id: .manual("handled"), type: .scrollView)
        handled.events = .replace([.refreshRequested: 3])
        var withheld = HostPatch(id: .manual("withheld"), type: .scrollView)
        withheld.events = .replace([.refreshRequested: 4])
        withheld.properties = [.isRefreshEnabled: .bool(false)]
        var carried = HostPatch(id: .manual("carried"), type: .itemsView)
        carried.driven = .replace([.isRefreshing: Self.binding])
        let root = try mounted([handled, withheld, carried, HostPatch(id: .manual("bare"), type: .scrollView)])

        XCTAssertEqual(try offer(of: "handled", in: root), .bool(true))
        XCTAssertEqual(try offer(of: "withheld", in: root), .bool(false), "the element says otherwise")
        XCTAssertEqual(try offer(of: "carried", in: root), .bool(true))
        XCTAssertNil(try offer(of: "bare", in: root), "nothing hears it")
    }

    /// A handler of the pull coming or going changes the offer the view is given, with nothing described of it.
    func testTheOfferFollowsWhatHearsThePull() throws {
        let views = Views()
        let runtime = HostRuntime(
            clock: StillClock(), reducesMotion: { false }, makeNative: { _ in views.made() }, log: { _ in })
        runtime.tree.apply(HostPatch(id: .manual("list"), type: .scrollView), complete: true)
        var heard = HostPatch(id: .manual("list"), type: .scrollView)
        heard.events = .replace([.refreshRequested: 5])

        runtime.tree.apply(heard, complete: false)
        XCTAssertTrue(try XCTUnwrap(views.last).changed.contains(.isRefreshEnabled), "a handler came")
        var unheard = HostPatch(id: .manual("list"), type: .scrollView)
        unheard.events = .replace([:])
        runtime.tree.apply(unheard, complete: false)
        XCTAssertTrue(try XCTUnwrap(views.last).changed.contains(.isRefreshEnabled), "and went")
    }

    /// The spinner a pull shows stays where a state carries `isRefreshing` or the element describes it, and goes at
    /// once where nothing would end it.
    func testThePullsSpinnerStaysOnlyWhereSomethingEndsIt() throws {
        let runtime = HostRuntime.still()
        var carried = HostPatch(id: .manual("carried"), type: .scrollView)
        carried.driven = .replace([.isRefreshing: Self.binding])
        var described = HostPatch(id: .manual("described"), type: .scrollView)
        described.properties = [.isRefreshing: .bool(false)]
        let root = try mounted([carried, described, HostPatch(id: .manual("bare"), type: .scrollView)], in: runtime)

        XCTAssertTrue(try XCTUnwrap(root.first(id: .manual("carried"))).reportRefreshRequested(in: runtime))
        XCTAssertTrue(try XCTUnwrap(root.first(id: .manual("described"))).reportRefreshRequested(in: runtime))
        XCTAssertFalse(try XCTUnwrap(root.first(id: .manual("bare"))).reportRefreshRequested(in: runtime))
    }

    /// A state of `isRefreshing` the pull writes into.
    private static let binding = HostStateBinding(state: 901, mode: .inOut, kind: .plain, laneKind: .boolean)

    /// `children` mounted in a stack.
    private func mounted(_ children: [HostPatch], in runtime: HostRuntime = .still()) throws -> MountedElement {
        var stack = HostPatch(id: .manual("stack"), type: .vStack)
        stack.children = .arranged(children)
        runtime.tree.apply(stack, complete: true)
        return try XCTUnwrap(runtime.tree.root)
    }

    /// The offer the view of the element `id` is given.
    private func offer(of id: String, in root: MountedElement) throws -> HostValue? {
        try XCTUnwrap(root.first(id: .manual(id))).presented(.isRefreshEnabled)
    }
}

/// The views a runtime made, each saying what it was last told changed.
@MainActor
private final class Views {
    private(set) var all: [ChangedView] = []
    var last: ChangedView? { all.last }

    func made() -> ChangedView {
        let view = ChangedView()
        all.append(view)
        return view
    }
}

/// A native half saying what it was last told changed.
@MainActor
private final class ChangedView: NativeElement {
    let presentsView = true
    private(set) var changed: Set<Prop> = []
    func standingValue(_ property: Prop) -> HostValue? { nil }
    func animates(_ property: Prop) -> Bool { false }
    func applied(changed: Set<Prop>, wasDescribed: Bool) { self.changed = changed }
    func presentFrame(_ changed: Set<Prop>) {}
    func leave() {}
    func arrangeChildren() {}
}
