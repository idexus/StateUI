// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A case's road to the host it runs on: the page it shows, the elements it finds by their ids, what the user does
/// to them, what their native controls hold, and what the case expects - never a widget, a pixel or a place.
/// Design: docs/design/host/conformance.md#a-session
@MainActor
@_spi(Host) public final class Session {
    /// The host the case runs on.
    public let driver: any HostDriver

    private let named: String
    private let report: (Failure) -> Void
    private var tree: MountedTree?

    /// How many of the case's expectations did not hold.
    public private(set) var failures = 0

    /// What the first expectation that did not hold said.
    public private(set) var firstFailure: String?

    /// What the case reached only through the host's own entry or record: an act or a read the driver says goes
    /// past the toolkit (`HostDriver.byHost`), on an element of which type and of which member - nil for every one.
    struct ByHost: Equatable {
        let element: String?
        let member: String?
        let why: String

        /// Whether it bears on what `covered` names.
        func bears(on covered: Covered) -> Bool {
            (element == nil || element == covered.element) && (member == nil || member == covered.member)
        }
    }

    /// Each act and read of the case that went past the toolkit, in order.
    private(set) var byHost: [ByHost] = []

    /// Notes `ability` where the driver says it goes past the toolkit.
    func note(_ ability: String, element: String? = nil, member: String? = nil) {
        guard let why = driver.byHost(ability) else { return }
        byHost.append(ByHost(element: element, member: member, why: "\(ability): \(why)"))
    }

    /// What a case throws once it has proved that its members are absent on this host: a view that refuses the
    /// keyboard and hears nothing never takes the focus there. The case's members are never had there, with why.
    public struct Absence: Error, Equatable {
        /// Why, in the words a verdict says it.
        public let why: String
    }

    /// The error that ends a case which proved its members absent here, saying `why`.
    public func absent(_ why: String) -> Absence {
        Absence(why: why)
    }

    init(driver: any HostDriver, case named: String, report: @escaping (Failure) -> Void) {
        self.driver = driver
        self.named = named
        self.report = report
    }

    /// Shows `page` in a window of its own on the host, its display frames at `clock`'s time where one is given.
    public func start(
        clock: TestClock? = nil, reducesMotion: Bool = false, _ page: @escaping @Sendable () -> any Page
    ) {
        tree = driver.start(clock: clock, reducesMotion: reducesMotion, page)
    }

    /// The element the page gave the id `id`.
    /// - Throws: where the page holds none.
    public func element(_ id: some Hashable) throws -> MountedElement {
        let key = ElementId.manual(String(describing: id))
        guard let element = tree?.root?.first(id: key) else { throw Missing(id: String(describing: id)) }
        return element
    }

    /// The entry of `identity` in the ItemsView `list`, built for a cell the platform holds.
    /// - Throws: where the platform holds no cell of it.
    public func item(_ identity: String, of list: MountedElement) throws -> MountedElement {
        guard let item = list.children.first(where: { $0.id == .manual(identity) }) else {
            throw Missing(id: "\(identity) of \(list.type.name)")
        }
        return item
    }

    /// Runs `application` on the host, its display frames at `clock`'s time where one is given. The case's first
    /// start is the application's first launch, and finds nothing kept; a start after it is the next launch.
    public func start(clock: TestClock? = nil, application: @escaping @Sendable () -> any Application) throws {
        if tree == nil { driver.forgetWhatIsKept() }
        tree = try driver.start(clock: clock, application: application)
    }

    /// The specimen of `element` a page of `Specimens.page(_:_:)` holds: the one of the id "specimen", or the one
    /// element of its kind - a span, an arrangement.
    public func specimen(_ element: String) throws -> MountedElement {
        if let found = try? self.element("specimen") { return found }
        return try self.element(ofType: NodeType(element))
    }

    /// The first element of `type` the tree holds, its root first: the application, a scene, a window.
    /// - Throws: where the tree holds none.
    public func element(ofType type: NodeType) throws -> MountedElement {
        guard let element = tree?.root.flatMap({ Self.first(type, in: $0) }) else { throw Missing(id: type.name) }
        return element
    }

    /// Every element of `type` the tree holds, in order: the root first, then each child's before the next child.
    public func elements(ofType type: NodeType) -> [MountedElement] {
        guard let root = tree?.root else { return [] }
        return Self.all(type, in: root)
    }

    /// Does `act` to `element` as the user does.
    public func perform(_ act: UserAct, on element: MountedElement) throws {
        if element.parent?.type == .itemsView {
            note("\(act) on an item of ItemsView", element: NodeType.itemsView.name)
        } else {
            note("\(act) on \(element.type.name)", element: element.type.name)
        }
        try driver.perform(act, on: element)
    }

    /// What the native control of `element` holds of `property`.
    public func held<Owner, Value>(_ property: ElementProperty<Owner, Value>, on element: MountedElement) throws -> Value? {
        note("read \(property.name) of \(element.type.name)", element: element.type.name, member: property.name)
        return try driver.held(property.token, on: element).flatMap { Value(propValue: $0) }
    }

    /// The menu `element` offers as the user meets it (`HostDriver.menu(of:)`).
    public func menu(of element: MountedElement) throws -> String {
        note("read the menu of \(element.type.name)")
        return try driver.menu(of: element)
    }

    /// Whether `element` holds the keyboard.
    public func focused(_ element: MountedElement) throws -> Bool {
        try driver.focused(element)
    }

    /// Whether a press at `point` of `element` reaches it, or what stands in it.
    public func reaches(_ element: MountedElement, at point: Point) throws -> Bool {
        try driver.reaches(element, at: point)
    }

    /// The question the window shows now; nil where it shows none.
    public func question() throws -> Question? {
        guard let root = tree?.root else { return nil }
        note("read a question")
        return try driver.question(over: root)
    }

    /// What the platform's screen reader was told to say, in order.
    public func announced() throws -> [String] {
        note("read what the screen reader said")
        return try driver.announced()
    }

    /// The colour `element` shows at `point` of its own, where StateUI draws it; nil where it shows nothing.
    public func color(of element: MountedElement, at point: Point) throws -> Color? {
        try driver.color(of: element, at: point)
    }

    /// Whether `element` shows `color` at `point` of its own, as a screen shows a colour StateUI draws.
    /// Design: docs/design/host/conformance.md#a-colour-drawn
    public func shows(_ color: Color, on element: MountedElement, at point: Point) throws -> Bool {
        Self.shows(try self.color(of: element, at: point), color)
    }

    /// Where `element` stands in its window, as the toolkit placed it.
    public func place(of element: MountedElement) throws -> Rect {
        try driver.place(of: element)
    }

    /// What the host wrote to its log.
    public func logged() throws -> [String] {
        note("read the log")
        return try driver.logged()
    }

    /// What the host's store keeps under `key` - of the scene the page is in where `inScene` - as the next launch
    /// reads it.
    public func kept(_ key: String, inScene: Bool = false) throws -> HostValue? {
        note("read what is kept")
        return try driver.kept(key, inScene: inScene)
    }

    /// Every element of `type` in `element`'s subtree, `element` first.
    private static func all(_ type: NodeType, in element: MountedElement) -> [MountedElement] {
        (element.type == type ? [element] : []) + element.children.flatMap { all(type, in: $0) }
    }

    /// The first element of `type` in `element`'s subtree, `element` first.
    private static func first(_ type: NodeType, in element: MountedElement) -> MountedElement? {
        if element.type == type { return element }
        for child in element.children {
            if let found = first(type, in: child) { return found }
        }
        return nil
    }

    /// Steps the host until `done` holds, at most 150 steps; the expectation after it says whether it did.
    public func settle(until done: () throws -> Bool) rethrows {
        for _ in 0..<150 {
            if try done() { return }
            driver.step()
        }
    }

    /// Steps the host until `done` holds, at most `seconds`: for what another process does, as a web view's page.
    /// Design: docs/design/host/conformance.md#a-session
    public func settle(for seconds: Int, until done: () throws -> Bool) rethrows {
        let end = ContinuousClock.now + .seconds(seconds)
        while ContinuousClock.now < end {
            if try done() { return }
            driver.step()
        }
    }

    /// One turn of the pump: the only way a case waits to see that nothing happens.
    public func turn() {
        driver.turn()
    }

    /// One display frame at the clock's time.
    public func frame() {
        driver.frame()
    }

    /// Expects `actual` to be `expected`.
    public func expect<Value: Equatable>(
        _ actual: Value, _ expected: Value, _ message: String = "", file: StaticString = #filePath, line: UInt = #line
    ) {
        guard actual != expected else { return }
        fail("\(Self.said(expected)) expected, \(Self.said(actual)) came" + (message.isEmpty ? "" : " - \(message)"),
             file: file, line: line)
    }

    /// Expects `actual` within `tolerance` of `expected`.
    public func expect(
        _ actual: Double?, _ expected: Double, within tolerance: Double, _ message: String = "",
        file: StaticString = #filePath, line: UInt = #line
    ) {
        if let actual, abs(actual - expected) <= tolerance { return }
        fail("\(expected) expected, \(actual.map { "\($0)" } ?? "nothing") came"
            + (message.isEmpty ? "" : " - \(message)"), file: file, line: line)
    }

    /// Expects `actual` to show `expected`, as a screen shows a colour StateUI draws.
    public func expect(
        _ actual: Color?, shows expected: Color, _ message: String = "", file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard !Self.shows(actual, expected) else { return }
        fail("\(Self.said(expected)) expected, \(Self.said(actual as Any)) came"
            + (message.isEmpty ? "" : " - \(message)"), file: file, line: line)
    }

    /// Whether `actual` is `expected` but for the last few steps of each channel, which smoothing an edge takes from
    /// a colour drawn whole.
    /// Design: docs/design/host/conformance.md#a-colour-drawn
    static func shows(_ actual: Color?, _ expected: Color) -> Bool {
        guard case .color(let red, let green, let blue, let alpha)? = actual?.propValue,
              case .color(let shownRed, let shownGreen, let shownBlue, let shownAlpha) = expected.propValue
        else { return false }
        return zip([red, green, blue, alpha], [shownRed, shownGreen, shownBlue, shownAlpha])
            .allSatisfy { abs(Int($0) - Int($1)) <= 4 }
    }

    /// Reports a failure of the case at `file` and `line`.
    public func fail(_ message: String, file: StaticString = #filePath, line: UInt = #line) {
        failures += 1
        if firstFailure == nil { firstFailure = message }
        report(Failure(message: "\(driver.host) · \(named): \(message)", file: file, line: line))
    }

    /// A value as a failure says it: what an optional holds, or nothing.
    private static func said(_ value: Any) -> String {
        let mirror = Mirror(reflecting: value)
        guard mirror.displayStyle == .optional else { return String(describing: value) }
        return mirror.children.first.map { said($0.value) } ?? "nothing"
    }

    /// An id the page does not hold.
    struct Missing: Error, CustomStringConvertible {
        let id: String
        var description: String { "no element has the id \"\(id)\"" }
    }
}
