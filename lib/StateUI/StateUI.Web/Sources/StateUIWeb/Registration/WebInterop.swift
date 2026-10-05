// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A control of the application's own on this host: an object that makes and holds the page's element it shows.
///
/// The host places, sizes and shows the element as it does its own, and holds the control for as long as its
/// element lives in the tree.
@MainActor
public protocol WebControl: AnyObject {
    /// The page's element the control shows.
    var element: WebPageElement { get }
}

/// An element of the page an application's control shows: one of the browser's own, or one the application defines
/// in its own JavaScript - a custom element its head's `Page` folder declares, which the page loads before the
/// application starts. The control says what it is through its attributes, and hears what it does through its
/// events.
@MainActor
public final class WebPageElement {
    /// The relay's number for the element.
    let node: Int32

    /// The listeners hung on the element, let go of with it.
    private(set) var listeners: [Int32] = []

    /// A new element of `tag` - `"canvas"`, or a custom element's own name, `"gallery-cube3d"`.
    public init(tag: String) {
        node = WebRelay.create(tag)
    }

    /// Sets an attribute, or takes it away for nil: what a custom element hears in its `attributeChangedCallback`.
    public func setAttribute(_ name: String, _ value: String?) {
        WebRelay.setAttribute(node, name, value)
    }

    /// Runs `action` whenever the element raises `event` - a DOM event's name, a custom element's own included.
    public func listen(_ event: String, _ action: @escaping @MainActor () -> Void) {
        let listener = WebRelay.listener(action)
        listeners.append(listener)
        WebRelay.listen(node, event, listener)
    }
}

/// The controls an application adds to this host - its own elements, each realized with a control of its own.
///
/// Said once, from the application's Web head, before `StateUIWeb.run(name:)`.
@MainActor
public enum StateUIControls {
    /// Adds an element of the APPLICATION'S OWN, realized with a control of its own: how the control is made, and
    /// which of the element's members it takes and raises.
    ///
    ///     StateUIControls.add(Cube3DContract.self, create: { _ in WebGLCube3DView() }) { cube in
    ///         cube.property(Cube3DContract.size) { control, size in control.cubeSize = size ?? 0.6 }
    ///     }
    ///
    /// What every view shares - margins, alignment, opacity, gestures, the frame reports - this host applies to the
    /// element, exactly as it does for the elements it realizes itself. A second registration of a contract
    /// replaces the first.
    ///
    /// - Parameters:
    ///   - contract: the element's contract.
    ///   - create: makes the control, once per element, handed what it reports through.
    ///   - members: registers the members the control takes and raises.
    public static func add<Realized: ElementContract, Made: WebControl>(
        _ contract: Realized.Type,
        create: @escaping (WebReports<Realized>) -> Made,
        members: (WebRegistration<Realized, Made>) -> Void = { _ in }
    ) {
        WebRegistrations.registry.add(
            contract,
            create: { reports in WebHostedView(create(WebReports(reports))) },
            members: { registration in members(WebRegistration(registration)) })
    }
}

/// What an element of the APPLICATION'S OWN tells the application: an event of its own, and a value its user
/// changed. Handed to the control where it is made, so the control names members of its contract and never a
/// handler.
public struct WebReports<Realized: ElementContract> {
    private let reports: Reports<Realized>

    init(_ reports: Reports<Realized>) {
        self.reports = reports
    }

    /// Raises one of the element's own events with the values its contract declares.
    public func raise<each Value: HostRepresentable>(
        _ event: ElementEvent<Realized, (repeat each Value)>,
        _ value: repeat each Value
    ) {
        reports.raise(event, repeat each value)
    }

    /// A value the USER changed: it lands on the state the element's value is carried in, and the event is raised
    /// with it.
    public func report<Owner: Contract, Raised: Contract, Value: HostRepresentable>(
        _ property: ElementProperty<Owner, Value>,
        _ value: Value,
        as event: ElementEvent<Raised, Value>
    ) {
        reports.report(property, value, as: event)
    }
}

/// How an application's own element is realized on this host, member by member: the properties its control takes,
/// and the events of its own it raises.
@MainActor
public final class WebRegistration<Realized: ElementContract, Made: WebControl> {
    private let registration: Registration<Realized, WebHostedView<Made>>

    init(_ registration: Registration<Realized, WebHostedView<Made>>) {
        self.registration = registration
    }

    /// A property the control takes, handed over as the type its contract declares - nil where the value is no
    /// longer described. A member of the element's contract or of a tier it wears; any other is refused, and said
    /// once.
    public func property<Owner: Contract, Value: HostRepresentable>(
        _ member: ElementProperty<Owner, Value>,
        _ apply: @escaping (Made, Value?) -> Void
    ) {
        registration.property(member) { hosted, value in apply(hosted.control, value) }
    }

    /// An event the control raises through its reports - recorded, so the core knows this host reports it.
    public func raises<Owner: Contract, Payload>(_ event: ElementEvent<Owner, Payload>) {
        registration.raises(event)
    }
}

/// A control of the application's own, standing in the tree as a view of this host: its element placed, sized and
/// shown like any other, the control held for as long as its element lives.
/// Design: docs/design/platforms/web/interop.md
@MainActor
final class WebHostedView<Control: WebControl>: WebDOMView {
    let control: Control

    init(_ control: Control) {
        self.control = control
        super.init(adopting: control.element.node)
    }

    override func detach() {
        for listener in control.element.listeners { WebRelay.forget(listener) }
        super.detach()
    }
}
