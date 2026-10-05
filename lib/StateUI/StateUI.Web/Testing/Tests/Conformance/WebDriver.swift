// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@_spi(Host) import StateUIConformance
@testable import StateUIWeb

/// The Web host as the conformance suite drives it, in a browser: each user's act as the browser takes the user's
/// own input - the mouse, the keyboard - or through the DOM's own call where the browser takes none of it, and each
/// read from the element itself, as the page holds it.
/// Design: docs/design/host/conformance.md#the-driver
@MainActor
final class WebDriver: HostDriver {
    let host = "Web"
    let cannot: [String: String] = [:]
    let platformHasNone = WebDriver.none()

    /// What the page holds none of: what StateUI's layout places and measures, each proven by its effect in another
    /// case.
    private static func none() -> [String: String] {
        var none: [String: String] = [:]
        for stack in ["HStack", "VStack"] {
            none["read spacing of \(stack)"] = "the page places a stack's children where StateUI's layout says; their frames prove it"
        }
        return none
    }

    var register: HostRegister { WebRealization.register }

    /// What the families ask of a driver that the Web's has no path for yet says so, and stays empty in the Web's
    /// column with why, rather than failing.
    func reason(cannot ability: String) -> String? {
        cannot[ability] ?? "the Web's driver has no path for it yet"
    }

    /// What the driver reaches past the page, through the host's own record - ✓.
    func byHost(_ ability: String) -> String? {
        if Ability(ability).readsATransform {
            return "the host's own transform: the page holds one matrix of it, its parts no longer told apart"
        }
        return Self.byHostReasons[ability]
    }

    private static let byHostReasons = [
        "read selectedItems of ItemsView": "the identities the host chose: the page marks a cell chosen, not which item it shows",
        "read windowType of Window": "the scenes the host keeps for the next start",
        "read windowValue of Window": "the scenes the host keeps for the next start",
    ]

    var renderer: WebRenderer?

    var liveViews: Int? { WebDOMView.liveCount }

    func start(
        clock: TestClock?, reducesMotion: Bool, @ViewBuilder _ page: @escaping @Sendable () -> any View
    ) -> MountedTree {
        let renderer = WebRenderer.running(clock: clock, reducesMotion: reducesMotion, page)
        self.renderer = renderer
        return renderer.runtime.tree
    }

    func start(clock: TestClock?, application: @escaping @Sendable () -> any Application) throws -> MountedTree {
        let renderer = WebRenderer.running(clock: clock, keeping: true, application: application)
        self.renderer = renderer
        return renderer.runtime.tree
    }

    func forgetWhatIsKept() {
        WebRenderer.forgetWhatIsKept()
    }

    func step() {
        renderer?.step()
    }

    func turn() {
        renderer?.runtime.pump.turn()
    }

    func frame() {
        renderer?.frame()
    }

    func held(_ property: Prop, on element: MountedElement) throws -> HostValue? {
        if let value = try structureHolds(property, on: element) { return value }
        let view = try self.view(of: element, reading: property)
        if let value = try reads(property, on: element, view: view) { return value }
        throw DriverCannot(reading: property, of: element)
    }

    /// The view of `element`.
    /// - Throws: `DriverCannot` where it has none.
    func view(of element: MountedElement, _ act: UserAct) throws -> WebDOMView {
        guard let view = (element.native as? WebElement)?.view else { throw DriverCannot(act, on: element) }
        return view
    }

    func view(of element: MountedElement, reading property: Prop) throws -> WebDOMView {
        guard let view = (element.native as? WebElement)?.view else { throw DriverCannot(reading: property, of: element) }
        return view
    }

    /// The renderer of the case.
    func running() throws -> WebRenderer {
        guard let renderer else { throw DriverCannot("reach a host before one starts") }
        return renderer
    }
}
