// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Handing a state over never makes a body its reader: a member whose value the library translates to the host's
// shape reads it as the differ describes its element.

import XCTest

@_spi(Host) @testable import StateUI

private final class Builds {
    var count = 0
}

/// A view handing a state to one member, counting its builds and reading nothing itself.
private struct Handing: View {
    let builds: Builds
    let member: () -> AnyView

    var body: some View {
        builds.count += 1
        return member()
    }
}

/// A tab view standing as the page, counting the builds of the view whose body it is.
private struct Tabs: View {
    let builds: Builds
    let tab: Binding<Int>

    var body: some View {
        builds.count += 1
        return TabView([1, 2, 3], selection: tab) { Text("\($0)") }
    }
}

/// A split view standing as the page, the same way.
private struct Split: View {
    let builds: Builds
    let shows: Binding<Bool>

    var body: some View {
        builds.count += 1
        return SplitView(shows) { Text("s") } detail: { Text("d") }
    }
}

@MainActor
final class ElementReadsTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    /// The body that hands `$x` to the member is built once; a write describes the element alone again, carrying
    /// its new value.
    private func assertTheElementReads(
        _ name: String, type: NodeType, prop: Prop, becomes value: PropValue,
        root: (Builds) -> some View, write: () -> Void
    ) {
        let builds = Builds()
        let renders = Renders()
        // At a page's root, where a tab view or a split view stands as the page itself.
        // At a page's root, as a window shows a view.
        renders.render(Node.page(root(builds)))
        XCTAssertEqual(builds.count, 1, name)

        write()
        let patch = renders.revisit(changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(builds.count, 1, "\(name): handing a state over makes no reader")
        XCTAssertEqual(patch.subtree.first { $0.type == type }?.props[prop], value,
                       "\(name): the element read the new value")
    }

    func testAPickerReadsItsChoice() {
        let size = State(wrappedValue: "M")
        assertTheElementReads("Picker", type: "Picker", prop: "selectedIndex", becomes: .number(2),
                              root: { Handing(builds: $0) { AnyView(Picker(["S", "M", "L"], selection: size.projectedValue)) } },
                              write: { size.wrappedValue = "L" })
    }

    func testATabViewReadsItsTab() {
        let tab = State(wrappedValue: 1)
        assertTheElementReads("TabView", type: "TabView", prop: "selectedTab", becomes: .number(2),
                              root: { Tabs(builds: $0, tab: tab.projectedValue) },
                              write: { tab.wrappedValue = 3 })
    }

    func testASplitViewReadsItsSidebar() {
        let shows = State(wrappedValue: true)
        assertTheElementReads("SplitView", type: "SplitView", prop: "showsSidebar", becomes: .bool(false),
                              root: { Split(builds: $0, shows: shows.projectedValue) },
                              write: { shows.wrappedValue = false })
    }

    func testAListReadsItsSelection() {
        let chosen = State<Int?>(wrappedValue: 1)
        assertTheElementReads("ItemsView", type: "ItemsView", prop: "selectedItems", becomes: .strings(["2"]),
                              root: { Handing(builds: $0) { AnyView(ItemsView(0..<3) { Text("\($0)") }.selection(chosen.projectedValue)) } },
                              write: { chosen.wrappedValue = 2 })
    }

    func testAMenuToggleReadsItsState() {
        let on = State(wrappedValue: false)
        assertTheElementReads("MenuToggle", type: "MenuToggle", prop: "isOn", becomes: .bool(true),
                              root: { Handing(builds: $0) { AnyView(Text("page").contextMenu { MenuToggle("Ruler", isOn: on.projectedValue) }) } },
                              write: { on.wrappedValue = true })
    }

    func testAToolbarToggleReadsItsState() {
        let on = State(wrappedValue: false)
        assertTheElementReads("ToolbarToggle", type: "ToolbarToggle", prop: "isOn", becomes: .bool(true),
                              root: { Handing(builds: $0) { AnyView(Text("page").toolbar { ToolbarToggle("Inspector", isOn: on.projectedValue) }) } },
                              write: { on.wrappedValue = true })
    }
}
