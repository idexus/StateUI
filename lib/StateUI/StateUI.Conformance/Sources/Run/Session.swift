// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A case's road to the host it runs on: the page it shows, the elements it finds by their ids, what the user does
/// to them, what their native controls hold, and what the case expects - never a widget.
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

    /// Shows `page` in a window of its own on the host, its display frames at `clock`'s time where one is given. The
    /// case's first start finds nothing kept, whatever earlier runs wrote.
    public func start(
        clock: TestClock? = nil, reducesMotion: Bool = false, @ViewBuilder _ page: @escaping @MainActor () -> any View
    ) {
        if tree == nil { driver.forgetWhatIsKept() }
        tree = driver.start(clock: clock, reducesMotion: reducesMotion, page)
    }

    /// The element the page gave the id `id`.
    /// - Throws: where the page holds none.
    public func element(_ id: some Hashable) throws -> MountedElement {
        let key = ElementID.manual(String(describing: id))
        guard let element = tree?.root?.first(id: key) else { throw Missing(id: String(describing: id)) }
        return element
    }

    /// Whether the element the page gave the id `id` stands shown; not where the page holds none.
    public func isShown(_ id: some Hashable) throws -> Bool {
        guard let shown = try? element(id) else { return false }
        return try held(VisualElementContract.isVisible, on: shown) == true
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
    public func start(clock: TestClock? = nil, application: @escaping @MainActor () -> any Application) throws {
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
        } else if case .dragAndDrop = act {
            // A drag reaches the views it crosses and lands on, as well as the one dragged.
            note("\(act) on \(element.type.name)")
        } else {
            note("\(act) on \(element.type.name)", element: element.type.name)
        }
        try driven { try driver.perform(act, on: element) }
    }

    /// What the native control of `element` holds of `property`.
    public func held<Owner, Value>(_ property: ElementProperty<Owner, Value>, on element: MountedElement) throws -> Value? {
        note("read \(property.name) of \(element.type.name)", element: element.type.name, member: property.name)
        return try driven { try driver.held(property.token, on: element).flatMap { Value(propValue: $0) } }
    }

    /// What `element`'s words are for, as its platform fills them in - a name it keeps, a new password, a code it
    /// received; on a platform that fills nothing in, a read it holds none of.
    public func filledIn(_ element: MountedElement) throws -> InputPurpose? {
        let ability = "read what the platform fills in of \(element.type.name)"
        if driver.platformHasNone[ability] != nil { throw DriverCannot(ability) }
        note(ability, element: element.type.name, member: TextInputContract.inputPurpose.name)
        return try driven {
            try driver.held(TextInputContract.inputPurpose.token, on: element).flatMap { InputPurpose(propValue: $0) }
        }
    }

    /// What a surface laid over the page stands on as its platform shows it - a sheet's - as a material; on a
    /// platform whose driver reads none, a read it holds none of. The read bears on the background it shows.
    public func ground(of element: MountedElement) throws -> Material? {
        let ability = "read the ground of \(element.type.name)"
        if driver.platformHasNone[ability] != nil { throw DriverCannot(ability) }
        note(ability, member: VisualElementContract.background.name)
        return try driven {
            try driver.held(VisualElementContract.background.token, on: element).flatMap { Material(propValue: $0) }
        }
    }

    /// The menu `element` offers as the user meets it (`HostDriver.menu(of:)`).
    public func menu(of element: MountedElement) throws -> String {
        note("read the menu of \(element.type.name)")
        return try driven { try driver.menu(of: element) }
    }

    /// The menu `button` opens (`HostDriver.buttonMenu(of:)`).
    public func buttonMenu(of button: MountedElement) throws -> String {
        note("read the menu \(button.type.name) opens")
        return try driven { try driver.buttonMenu(of: button) }
    }

    /// The bar at `edge` of `page` as the user meets it (`HostDriver.bar(of:at:)`): its title's, unsaid.
    public func bar(of page: MountedElement, at edge: ToolbarEdge = .top) throws -> String {
        note(edge == .top ? "read the bar of \(page.type.name)" : "read the bar at the foot of \(page.type.name)")
        return try driven { try driver.bar(of: page, at: edge) }
    }

    /// Whether `element` holds the keyboard.
    public func focused(_ element: MountedElement) throws -> Bool {
        note("read the focus of \(element.type.name)", element: element.type.name)
        return try driven { try driver.focused(element) }
    }

    /// Whether a press at `point` of `element` reaches it, or what stands in it.
    public func reaches(_ element: MountedElement, at point: Point) throws -> Bool {
        note("read what reaches \(element.type.name)", element: element.type.name)
        return try driven { try driver.reaches(element, at: point) }
    }

    /// Whether assistive technology meets `element` as a heading, whatever its level.
    public func isHeading(_ element: MountedElement) throws -> Bool {
        note(
            "read whether \(element.type.name) is a heading", element: element.type.name,
            member: VisualElementContract.accessibilityHeading.name)
        return try driven { try driver.isHeading(element) }
    }

    /// The ids of the children of `layout`, in the order its toolkit draws them, back to front.
    public func drawingOrder(of layout: MountedElement) throws -> [ElementID] {
        note("read the drawing order of \(layout.type.name)")
        return try driven { try driver.drawingOrder(of: layout).map(\.id) }
    }

    /// The question the window shows now; nil where it shows none.
    public func question() throws -> Question? {
        guard let root = tree?.root else { return nil }
        note("read a question")
        return try driven { try driver.question(over: root) }
    }

    /// What the platform's screen reader was told to say, in order.
    public func announced() throws -> [String] {
        note("read what the screen reader said")
        return try driven { try driver.announced() }
    }

    /// The platform's bars over the window's edges, as a phone's stand, where the host's test window stands under
    /// none (`HostDriver.standUnderSystemBars`).
    public func standUnderSystemBars(top: Double, bottom: Double) {
        driver.standUnderSystemBars(top: top, bottom: bottom)
        driver.step()
    }

    /// The theme the platform shows the application in now.
    public func theme() throws -> ColorScheme {
        note("read the theme the application shows in")
        return try driven { try driver.theme() }
    }

    /// The accent the platform draws the application's controls in now.
    public func accent() throws -> Color {
        note("read the accent the application draws in")
        return try driven { try driver.accent() }
    }

    /// The address of the driver's HTTP server (`HostDriver.served()`).
    public func served() throws -> String {
        note("serve a request")
        return try driven { try driver.served() }
    }

    /// The requests for `/held` the driver's server took, and those stopped (`HostDriver.held()`).
    public func held() throws -> (taken: Int, stopped: Int) {
        note("count the requests held")
        return try driven { try driver.held() }
    }

    /// The file dialog the window shows now; nil where it shows none.
    public func fileDialog() throws -> FileDialog? {
        guard let root = tree?.root else { return nil }
        note("read a file dialog")
        return try driven { try driver.fileDialog(over: root) }
    }

    /// What the share sheet over the window offers now - its words, then its link on a line of its own; nil where
    /// none shows.
    public func shared() throws -> String? {
        guard let root = tree?.root else { return nil }
        note("read a share sheet")
        return try driven { try driver.shared(over: root) }
    }

    /// What the host handed the system to launch, in order: an address as written, a file by its name.
    public func launched() throws -> [String] {
        note("read what was launched")
        return try driven { try driver.launched() }
    }

    /// The color `element` shows at `point` of its own, where StateUI draws it; nil where it shows nothing.
    public func color(of element: MountedElement, at point: Point) throws -> ShownColor? {
        note("read the color of \(element.type.name)", element: element.type.name)
        return try driven { try driver.color(of: element, at: point).map(ShownColor.init) }
    }

    /// Whether `element` shows `color` at `point` of its own, as a screen shows a color StateUI draws.
    /// Design: docs/design/host/conformance.md#a-color-drawn
    public func shows(_ color: Color, on element: MountedElement, at point: Point) throws -> Bool {
        Self.shows(try self.color(of: element, at: point), color)
    }

    /// The colors `element` shows at each of `points` of its own, read at once; nil where it shows nothing.
    /// Design: docs/design/host/conformance.md#a-color-drawn
    public func colors(of element: MountedElement, at points: [Point]) throws -> [ShownColor?] {
        note("read the color of \(element.type.name)", element: element.type.name)
        return try driven { try driver.colors(of: element, at: points).map { $0.map(ShownColor.init) } }
    }

    /// Whether `element` shows `color` at each of `points` of its own, read at once.
    /// Design: docs/design/host/conformance.md#a-color-drawn
    public func shows(_ color: Color, on element: MountedElement, at points: [Point]) throws -> [Bool] {
        try colors(of: element, at: points).map { Self.shows($0, color) }
    }

    /// Where `element` stands in its window, as the toolkit placed it.
    public func place(of element: MountedElement) throws -> Rect {
        note("read where \(element.type.name) stands", element: element.type.name)
        return try driven { try driver.place(of: element) }
    }

    /// What the host wrote to its log.
    public func logged() throws -> [String] {
        note("read the log")
        return try driven { try driver.logged() }
    }

    /// The words the host's store keeps under `key` - of the scene the page is in where `inScene` - as the next
    /// launch reads them.
    public func kept(_ key: String, inScene: Bool = false) throws -> String? {
        note("read what is kept")
        return try driven { try driver.kept(key, inScene: inScene) }
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

    /// Steps the host until `done` holds, at most 150 steps; a wait that runs out fails the case - or ends it as
    /// what the driver could not do while it waited.
    /// Design: docs/design/host/conformance.md#a-session
    public func settle(file: StaticString = #filePath, line: UInt = #line, until done: () throws -> Bool) rethrows {
        cannot = nil
        for _ in 0..<150 {
            if try done() { return }
            driver.step()
        }
        if try !done() { ranOut(file: file, line: line) }
    }

    /// Steps the host until `done` holds, at most `seconds`: for what another process does, as a web view's page; a
    /// wait that runs out fails the case.
    /// Design: docs/design/host/conformance.md#a-session
    public func settle(
        for seconds: Int, file: StaticString = #filePath, line: UInt = #line, until done: () throws -> Bool
    ) rethrows {
        cannot = nil
        let end = ContinuousClock.now + .seconds(seconds)
        while ContinuousClock.now < end {
            if try done() { return }
            driver.step()
        }
        if try !done() { ranOut(file: file, line: line) }
    }

    /// What the driver could not do while the case waited last.
    private var cannot: DriverCannot?

    /// What the driver could not do first, though the case let it pass: a case that passes else ends as that.
    private(set) var unmet: DriverCannot?

    /// A wait ran out: on what the driver could not do while it waited, which the case ends as, else on what never
    /// came.
    private func ranOut(file: StaticString, line: UInt) {
        guard cannot == nil else { return }
        fail("what the case waited for never came", file: file, line: line)
    }

    /// What `read` answers of the driver; what the driver cannot do is kept, then thrown.
    private func driven<Value>(_ read: () throws -> Value) throws -> Value {
        do {
            return try read()
        } catch let cannot as DriverCannot {
            self.cannot = cannot
            unmet = unmet ?? cannot
            throw cannot
        }
    }

    /// One turn of the pump: the only way a case waits to see that nothing happens.
    public func turn() {
        driver.turn()
    }

    /// Display frames every 16 ms of `clock` - the display's own pace - while it stands before `end` milliseconds.
    public func frames(of clock: TestClock, until end: Double) {
        while clock.now < end {
            clock.now += 16
            driver.frame()
        }
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

    /// Expects `actual` to show `expected`, as a screen shows a color StateUI draws.
    public func expect(
        _ actual: ShownColor?, shows expected: Color, _ message: String = "", file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard !Self.shows(actual, expected) else { return }
        fail("\(Self.said(expected)) expected, \(Self.said(actual as Any)) came"
            + (message.isEmpty ? "" : " - \(message)"), file: file, line: line)
    }

    /// Whether `actual` shows `expected`; nothing shown shows no color.
    static func shows(_ actual: ShownColor?, _ expected: Color) -> Bool {
        actual?.shows(expected) ?? false
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
