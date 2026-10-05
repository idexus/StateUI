// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What an APPLICATION registers with this host, beside the elements the host realizes itself: the acts it performs,
/// by the host layer's rule. Said once, before `StateUIWeb.run(name:)`.
/// Design: docs/design/platforms/web/interop.md
@MainActor
enum WebInterop {
    /// The application's acts, performed where no act of the library's answers the call.
    static let acts = InteropActs<WebDOMView>()
}

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

    /// Runs `action` whenever the element raises `event`, handed the number its `detail` carries - a custom
    /// element's `CustomEvent`, `new CustomEvent("lamptap", { detail: 2 })`.
    public func listen(_ event: String, _ action: @escaping @MainActor (Double) -> Void) {
        listen(event) { action(WebRelay.eventDetail) }
    }

    /// Runs `action` whenever the element raises `event`, handed the words its `detail` carries - a custom element's
    /// `CustomEvent`, `new CustomEvent("mapclick", { detail: "50.06 19.94" })`.
    public func listen(_ event: String, words action: @escaping @MainActor (String) -> Void) {
        listen(event) { action(WebRelay.eventWords) }
    }

    /// Calls the element's own method `name`, with nothing - a custom element's, `flash()`.
    public func call(_ name: String) {
        WebRelay.callMethod(node, name)
    }
}

/// The application's own scripts - its head's `Page/*.js` - as Swift reaches them: an act they answer, and what
/// they tell. A script answers an act by name on `StateUI.acts`, and tells with `StateUI.tell(name, words)`:
///
///     StateUI.acts.readClipboard = () => navigator.clipboard.readText();
///     StateUI.tell("battery", `${battery.level} ${battery.charging}`);
///
/// Words cross both ways: an application says in them what it hands over and reads back.
@MainActor
public enum StateUIScripts {
    /// Calls the act `name` of the application's scripts, handing it `words`; answers the words its promise gives,
    /// "" for none, and throws why where it breaks - or where no script answers that name.
    public static func call(_ name: String, _ words: String = "") async throws -> String {
        try await withCheckedThrowingContinuation { (settled: CheckedContinuation<String, any Error>) in
            WebRelay.callScript(name, words, WebRelay.once {
                let words = WebRelay.scriptWords
                if WebRelay.scriptKept {
                    settled.resume(returning: words)
                } else {
                    settled.resume(throwing: StateUIError(message: words))
                }
            })
        }
    }

    /// Runs `action` each time the application's scripts tell `name`, handed the words told - the last told before
    /// first, where they told it already.
    public static func hear(_ name: String, _ action: @escaping @MainActor (String) -> Void) {
        WebRelay.listenToScript(name, WebRelay.listener { action(WebRelay.scriptWords) })
    }
}

/// The acts an application performs on this host - what its own calls, `stateUICall` and an `Aim`, reach.
///
/// Said once, from the application's Web head, before `StateUIWeb.run(name:)`.
@MainActor
public enum StateUIActs {
    /// Performs an act of the application's - one no control stands behind - when the application calls it with
    /// `stateUICall`. A performer may await - a browser reads its clipboard asynchronously - and the call is
    /// answered once it returns; what it throws fails the call. A second registration replaces the first.
    ///
    ///     StateUIActs.add(GalleryContract.readClipboard) {
    ///         try await StateUIScripts.call("readClipboard")
    ///     }
    public static func add<
        Owner: ApplicationTier, each Argument: HostRepresentable, each Answer: HostRepresentable
    >(
        _ act: ElementAct<Owner, (repeat each Argument), (repeat each Answer)>,
        _ perform: @escaping @MainActor (repeat each Argument) async throws -> (repeat each Answer)
    ) {
        WebInterop.acts.add(act, perform)
    }

    /// Performs an act AIMED at one of the application's own elements, when the application calls it through an
    /// `Aim`: the performer is handed the element's control. An aim at nothing, or at an element no longer on
    /// screen, fails the call with that reason.
    ///
    ///     StateUIActs.add(RatingBarContract.flash, on: RatingBarElement.self) { bar in
    ///         bar.element.call("flash")
    ///     }
    public static func add<
        Owner: Contract, Made: WebControl, each Argument: HostRepresentable, each Answer: HostRepresentable
    >(
        _ act: ElementAct<Owner, (repeat each Argument), (repeat each Answer)>,
        on control: Made.Type,
        _ perform: @escaping @MainActor (Made, repeat each Argument) async throws -> (repeat each Answer)
    ) {
        WebInterop.acts.add(act, control: { ($0 as? WebHostedView<Made>)?.control }, perform)
    }
}

/// The events an application raises through this host - the ones no control raises, heard by every
/// `HostEvents.on`.
public enum StateUIEvents {
    /// Declares an event of the application's this host raises, where its source is wired: a handler listening for
    /// an event nothing declared is told, once, that it will not hear it.
    ///
    ///     StateUIEvents.raises(GalleryContract.batteryChanged)
    @MainActor
    public static func raises<Owner: ApplicationTier, Payload>(_ event: ElementEvent<Owner, Payload>) {
        WebRegistrations.registry.raises(event)
    }

    /// Raises an event of the application's - one no control raises - with the values its contract declares;
    /// every `HostEvents.on` subscription to the member hears it. Answers how many heard it.
    ///
    ///     StateUIEvents.raise(GalleryContract.batteryChanged, level, charging)
    @discardableResult
    public nonisolated static func raise<Owner: ApplicationTier, each Value: HostRepresentable>(
        _ event: ElementEvent<Owner, (repeat each Value)>,
        _ value: repeat each Value
    ) -> Int {
        CoreLink().raise(event, repeat each value)
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

    /// The children of one contract the control draws itself - a map's markers - handed over whole, in the tree's
    /// order, whenever the element's children change: one added, moved, taken away, or given another value. Such a
    /// child has no element of its own on the page. `members` are what the control realizes of each child - a
    /// property or an event of the child's contract or of a tier it wears; anything else is left out, and said once.
    ///
    ///     map.children(MarkerContract.self, members: [MarkerContract.location, MarkerContract.selected]) { control, markers in
    ///         control.show(markers)
    ///     }
    public func children<Child: ElementContract>(
        _ contract: Child.Type,
        members: [any ContractMember],
        _ apply: @escaping (Made, [WebChild<Child>]) -> Void
    ) {
        registration.children(contract, members: members) { hosted, children in
            apply(hosted.control, children.map(WebChild.init))
        }
    }
}

/// A child element the control draws itself - a map's marker: its values as the types its contract declares, and the
/// reports its events leave through. Two are equal when they are the same child, for as long as it lives, so a
/// control keeps what it drew for one by it.
public struct WebChild<Child: ElementContract>: Hashable {
    private let child: ChildElement<Child>

    init(_ child: ChildElement<Child>) {
        self.child = child
    }

    /// One of the child's values, as the type its contract declares - nil where it is not described.
    public func value<Owner: Contract, Value: HostRepresentable>(_ property: ElementProperty<Owner, Value>) -> Value? {
        child.value(property)
    }

    /// What the child's events and the user's values on it leave through.
    public var reports: WebReports<Child> {
        WebReports(child.reports)
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
