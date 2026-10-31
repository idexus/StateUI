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
        for shape in ["Capsule", "Ellipse", "Line", "Path", "Polygon", "Polyline", "Rectangle"] {
            for member in ["contentMode", "geometryTransform"] {
                none["read \(member) of \(shape)"] =
                    "the page holds the path placed in its room, its \(member) worked in; its drawing proves it"
            }
        }
        for field in ["TextField", "SearchField", "TextEditor"] {
            none["read maximumLength of \(field)"] =
                "the browser bounds UTF-16 units, not characters, so the host cuts what is typed; typing proves it"
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
        if ability.hasPrefix("read holdDuration of ") {
            return "the relay's own wait: a page holds no hold of the browser's"
        }
        // An act is noted with the element it is done on: its reason is the act's, on any element.
        return Self.byHostReasons[ability] ?? Self.byHostReasons[Ability(ability).act]
    }

    private static let byHostReasons = [
        "read step of Stepper": "the step the host takes: the page's field holds none",
        "openLink": "the host's entry the page's address with a fragment reaches, no address loaded",
        "switchAway": "the notice the browser gives as the user goes elsewhere, told by the driver: a page moves no window",
        "switchBack": "the notice the browser gives as the user comes back, told by the driver: a page moves no window",
        "minimize": "the notice the browser gives as the page's tab hides, told by the driver: a page hides no tab",
        "restore": "the notice the browser gives as the page's tab shows, told by the driver: a page shows no tab",
        "close on Window": "the notice the browser gives as it leaves the page, told by the driver: a page closes no tab",
        "read selectedItems of ItemsView": "the identities the host chose: the page marks a cell chosen, not which item it shows",
        "read windowType of Window": "the scenes the host keeps for the next start",
        "read windowValue of Window": "the scenes the host keeps for the next start",
        "read a file dialog": "the dialog the relay holds on a page a test drives, which the browser never shows",
        "read what was launched": "the relay's own record of what it would open, which a test holds back",
        "answerFiles": "the relay's answer handed the driver's files, no dialog shown",
        "answerShare": "the relay's answer handed the driver's choice, no share sheet shown",
        "read a share sheet": "the share sheet the relay holds on a page a test drives, which the browser never shows",
        "dragAndDrop": "the DOM's drag events dispatched by the driver, no drag the browser began",
        "dropFiles": "the DOM's drag events dispatched by the driver with its files, no drag the browser began",
        "sweep": "the hand handed to the host's entry with its speed, no pointer sent",
        "notch": "a wheel's notches handed to the host's entry, no wheel sent",
    ]

    var renderer: WebRenderer?

    /// What the host writes to its log, as the driver hears it.
    let written = WebLogLines()

    var liveViews: Int? { WebDOMView.liveCount }
    var liveViewKinds: [String: Int]? { Dictionary(WebDOMView.liveKinds.values.map { ($0, 1) }, uniquingKeysWith: +) }

    func start(
        clock: TestClock?, reducesMotion: Bool, @ViewBuilder _ page: @escaping @MainActor () -> any View
    ) -> MountedTree {
        written.listen()
        emptyFiles()
        let renderer = WebRenderer.running(clock: clock, reducesMotion: reducesMotion, page)
        self.renderer = renderer
        return renderer.runtime.tree
    }

    func start(clock: TestClock?, application: @escaping @MainActor () -> any Application) throws -> MountedTree {
        written.listen()
        emptyFiles()
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
        if [.menuItem, .menuToggle, .menu].contains(element.type), let value = try menuItemHolds(property, on: element) { return value }
        if NodeType.toolbarItemTypes.contains(element.type), let value = try toolbarItemHolds(property, on: element) {
            return value
        }
        if element.type == .toolbarGroup, let group = try barView(of: element) {
            switch property {
            case .background, .stroke, .lineWidth, .shape: if let value = try boxHolds(property, group) { return value }
            case .padding: if let value = try wordsHolds(property, group.node) { return value }
            case .spacing: return try WebBrowser.number("parseFloat(getComputedStyle(e).columnGap) || 0", on: group.node)?.propValue
            default: break
            }
        }
        if element.type == .textSpan, let value = try spanHolds(property, on: element) { return value }
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

    /// What the host wrote to its log since the case's host started.
    func logged() throws -> [String] {
        written.lines
    }

    /// The renderer of the case.
    func running() throws -> WebRenderer {
        guard let renderer else { throw DriverCannot("reach a host before one starts") }
        return renderer
    }
}

/// The host's log, line by line, as the driver hears it.
final class WebLogLines: @unchecked Sendable {
    private(set) var lines: [String] = []

    /// Listens to the host's log from now on.
    @MainActor func listen() {
        lines = []
        WebRenderer.log = HostLog(host: "Web") { [self] line in
            lines.append(line)
            print(line, terminator: "")
        }
    }
}
