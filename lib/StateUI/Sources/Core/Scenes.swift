// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The scenes an application has open, and the tree the host keeps its platform
// windows in step with.
// Design: docs/design/core/scenes.md#the-scene-tree


/// The name a scene keeps a value under, and what kind of value it is -
/// `@State(sceneKey:)`'s key. This library's own.
///
///     extension SceneKey {
///         static let section = SceneKey("section", of: Int.self)
///     }
///
///     @State(sceneKey: .section) private var section = 0
///
/// Each scene keeps its own value under the name, handed back with the scene when
/// the system restores it; where a platform restores no scenes, the value lives as
/// long as its scene. A value every scene shares is a `PersistentKey`.
public struct SceneKey: Hashable, Sendable, CustomStringConvertible {
    /// The name - what the value is written down under.
    public let name: String

    /// What kind of value it holds, taken from the type it was declared with.
    public let kind: PersistentKind

    /// A key from its name and the type of the value it keeps.
    ///
    /// - Parameters:
    ///   - name: the application's own name for it.
    ///   - type: the type of the state kept under it.
    public init<Value: PersistentValue>(_ name: String, of type: Value.Type) {
        self.name = name
        kind = Value.persistentKind
    }

    /// The name, so an interpolated diagnostic prints it plainly.
    public var description: String { name }
}

/// What a scene's build declared about one of its window groups - what opening a
/// window is checked against, and what a restored window is read with.
struct GroupShape {
    /// The type of value the group opens one window per; nothing for a group of one.
    let valueType: Any.Type?

    /// A value read back out of the text it was written down as.
    let restore: (String) -> AnyHashable?

    /// Whether this shape takes a value of `type` - nothing meaning none.
    func takes(_ type: Any.Type?) -> Bool {
        switch (valueType, type) {
        case (nil, nil): return true
        case let (declared?, given?): return ObjectIdentifier(declared) == ObjectIdentifier(given)
        default: return false
        }
    }
}

/// A window a scene has open beside its main one.
struct OpenedWindow: Equatable {
    /// Its group's kind.
    let type: WindowType

    /// Its number in its scene, in opening order - what keeps it the same window when
    /// its value changes.
    let serial: Int

    /// The value it stands for, where its group opens one per value.
    var value: AnyHashable?

    /// That value written down, the way the platform keeps it.
    var text: String?

    /// What the tree knows it by.
    var key: String { "\(type.name) \(serial)" }
}

/// One open scene: what it has open beside its main window, what the platform
/// kept for it, and the sessions it hands the views under it.
final class SceneRecord: @unchecked Sendable {
    /// Its number - "1" for the first scene - which is also its key in the tree.
    let id: String

    /// What it has open beside its main window, in the order they opened.
    @State var windows: [OpenedWindow] = []

    /// Its session - what a view in the scene resolves as `SceneSession`.
    let session: SceneSession

    /// The groups its last build declared, by kind - written by that build.
    var declared: [WindowType: GroupShape] = [:]

    /// Whether the platform has handed it a window; the scene an application starts
    /// with waits for the first one.
    var handedOver: Bool

    /// The last number given to one of its windows.
    private var serial = 0

    /// Each window's session, kept while the window is open.
    private var windowSessions: [String: WindowSession] = [:]

    /// Held around the three tables below: a scene key's write lands from under its
    /// state's lock, from any thread.
    private let guarded = Lock()

    /// What the platform kept for the scene's keys, by name.
    private var restored: [String: PropValue] = [:]

    /// The storage standing for each key - one key, one piece of state.
    private var keyed: [String: AnyObject] = [:]

    /// The keys written since the host last took them, each with its last value.
    private var waiting: [String: PropValue] = [:]

    /// A scene, by its number, and whether the platform has handed it a window.
    init(id: String, handedOver: Bool) {
        self.id = id
        self.handedOver = handedOver
        session = SceneSession(id: id)
        session.record = self
    }

    // MARK: - Its windows

    /// Opens the window of a group that opens one.
    func open(_ type: WindowType) throws {
        try check(type, takes: nil)

        guard Scenes.opensWindows else { throw WindowError.unsupported }
        guard !windows.contains(where: { $0.type == type }) else { throw WindowError.alreadyOpen }

        windows.append(OpenedWindow(type: type, serial: nextSerial(), value: nil, text: nil))
    }

    /// Opens the window for a value.
    func open<Value: Codable & Hashable>(_ type: WindowType, value: Value) throws {
        try check(type, takes: Value.self)

        guard Scenes.opensWindows else { throw WindowError.unsupported }

        let key = AnyHashable(value)

        guard !windows.contains(where: { $0.type == type && $0.value == key }) else {
            throw WindowError.alreadyOpen
        }

        windows.append(
            OpenedWindow(type: type, serial: nextSerial(), value: key, text: try ValueText.write(value)))
    }

    /// Closes the window of a group that opens one.
    func close(_ type: WindowType) throws {
        try check(type, takes: nil)

        guard let index = windows.firstIndex(where: { $0.type == type }) else {
            throw WindowError.notOpen
        }

        windows.remove(at: index)
    }

    /// Closes the window for a value.
    func close<Value: Codable & Hashable>(_ type: WindowType, value: Value) throws {
        try check(type, takes: Value.self)

        let key = AnyHashable(value)

        guard let index = windows.firstIndex(where: { $0.type == type && $0.value == key }) else {
            throw WindowError.notOpen
        }

        windows.remove(at: index)
    }

    /// Closes one of its windows by its key - what that window's session asks for.
    func closeWindow(key: String) throws {
        guard windows.contains(where: { $0.key == key }) else { throw WindowError.notOpen }

        closed(key: key)
    }

    /// Makes one of its windows about another value - the window's own binding.
    func retarget<Value: Codable & Hashable>(_ serial: Int, to value: Value) {
        guard let index = windows.firstIndex(where: { $0.serial == serial }) else { return }

        windows[index].value = AnyHashable(value)
        windows[index].text = try? ValueText.write(value)
    }

    /// The user closed one of its windows; a report about one already gone changes
    /// nothing.
    func closed(key: String) {
        windows.removeAll { $0.key == key }
    }

    /// The system restored one of its windows: back it goes where the scene still
    /// declares its kind and the text reads as its value, and nowhere else.
    /// Design: docs/design/core/scenes.md#what-the-platform-keeps
    func restored(kind name: String, text: String?) {
        let type = WindowType(name)

        guard let shape = declared[type] else { return }

        guard let text else {
            guard shape.valueType == nil, !windows.contains(where: { $0.type == type }) else { return }

            windows.append(OpenedWindow(type: type, serial: nextSerial(), value: nil, text: nil))
            return
        }

        guard shape.valueType != nil, let value = shape.restore(text),
            !windows.contains(where: { $0.type == type && $0.value == value })
        else { return }

        windows.append(OpenedWindow(type: type, serial: nextSerial(), value: value, text: text))
    }

    /// The session of one of its windows, made once and kept.
    func windowSession(_ key: String) -> WindowSession {
        if let standing = windowSessions[key] {
            return standing
        }

        let made = WindowSession(key: key, record: self)
        windowSessions[key] = made
        return made
    }

    /// Lets go of the sessions of windows that have closed; its main window's
    /// is kept for as long as the scene is.
    func keepWindowSessions() {
        let open = Set(windows.map(\.key) + [SceneElement.mainKey])

        windowSessions = windowSessions.filter { open.contains($0.key) }
    }

    /// Checks a kind against what the scene declares.
    private func check(_ type: WindowType, takes valueType: Any.Type?) throws {
        guard let shape = declared[type] else { throw WindowError.undeclared(type) }
        guard shape.takes(valueType) else { throw WindowError.wrongValue(type) }
    }

    /// The next number for one of its windows.
    private func nextSerial() -> Int {
        serial += 1
        return serial
    }

    // MARK: - What it keeps

    /// Takes what the platform kept for the scene's keys - before its first
    /// build, which is where the states claiming them are built.
    func restore(_ values: [String: PropValue]) {
        guarded.withLock { restored = values }
    }

    /// The storage a key of this scene means: the one standing, or the offered one
    /// adopted, with what the platform kept landed in it.
    func claim(_ name: String, orAdopt storage: AnyObject, landing land: (PropValue) -> Void) -> AnyObject {
        let (owner, held): (AnyObject, PropValue?) = guarded.withLock {
            if let standing = keyed[name] { return (standing, nil) }

            keyed[name] = storage
            return (storage, restored[name])
        }

        if let held {
            land(held)
        }

        return owner
    }

    /// Marks a key as needing to be kept, replacing whatever value was
    /// waiting. Runs under the state's lock, so it records and nothing else.
    func record(_ name: String, _ value: PropValue) {
        guarded.withLock { waiting[name] = value }
    }

    /// How many keys are waiting to be kept.
    var pending: Int { guarded.withLock { waiting.count } }

    /// The keys waiting to be kept, sorted by name, taken.
    func takeWaiting() -> [(name: String, value: PropValue)] {
        guarded.withLock {
            let taken = waiting.sorted { $0.key < $1.key }
            waiting.removeAll(keepingCapacity: true)
            return taken.map { (name: $0.key, value: $0.value) }
        }
    }
}

/// Every scene the application has open.
final class Scenes: @unchecked Sendable {
    /// The one there is: a process runs one application.
    static let shared = Scenes()

    /// The scenes in opening order - a state the root reads, so a scene opening or
    /// closing builds the application again and no scene that stays.
    @State var list: [SceneRecord] = [SceneRecord(id: "1", handedOver: false)]

    /// The number the next scene gets.
    private var next = 2

    /// The scene being built now, while the differ is inside one - what a
    /// `@State(sceneKey:)` made during the build claims from.
    var building: SceneRecord?

    private init() {}

    /// Starts again with one scene, waiting for the platform's first window -
    /// what an application is given as it registers.
    func reset() {
        list = [SceneRecord(id: "1", handedOver: false)]
        next = 2
    }

    /// The scene with a number, if it is open - read off the storage, so no build that
    /// asks becomes the list's reader.
    func record(id: String) -> SceneRecord? {
        _list.storage.value.first { $0.id == id }
    }

    /// Where a scene stands in the application's list - what the host's
    /// report about each scene's apply is ordered by.
    func index(of id: String) -> Int? {
        _list.storage.value.firstIndex { $0.id == id }
    }

    /// Whether the platform opens a window beside another: a desktop and an iPad do, a
    /// phone does not, and a host that has not said does.
    static var opensWindows: Bool {
        let device = StandardEnvironment.device

        switch device.formFactor {
        case .desktop, .unknown: return true
        case .tablet: return device.platform == "iOS"
        default: return false
        }
    }

    /// Opens another scene, for the host to open a platform window for.
    func openScene() throws {
        guard Scenes.opensWindows else { throw WindowError.unsupported }

        list.append(SceneRecord(id: "\(next)", handedOver: true))
        next += 1
    }

    /// Ends a scene from the interface - its session's `close()`.
    func close(_ record: SceneRecord) throws {
        guard Scenes.opensWindows else { throw WindowError.unsupported }
        guard _list.storage.value.contains(where: { $0 === record }) else { throw WindowError.notOpen }

        ended(record)
    }

    /// The platform handed over a window nobody here asked for: the scene waiting for
    /// its first window takes it, or a new scene does.
    /// Design: docs/design/core/scenes.md#connecting-and-ending
    func connected(restoring values: [String: PropValue]) {
        let standing = _list.storage.value

        if let waiting = standing.first(where: { !$0.handedOver }) {
            waiting.handedOver = true
            waiting.restore(values)
        } else {
            let record = SceneRecord(id: "\(next)", handedOver: true)
            next += 1
            record.restore(values)
            list.append(record)
        }

        // The host renders into the window as soon as this returns.
        Renderer.shared.setNeedsRender()
    }

    /// A scene's main window has gone, and the scene with it.
    func ended(_ record: SceneRecord) {
        list.removeAll { $0 === record }
        Inspector.ended(record)
    }

    /// Every key the open scenes have waiting, as the acts that keep them.
    func takeSaves() -> [ActCall] {
        _list.storage.value.flatMap { record in
            record.takeWaiting().map {
                ActCall(ApplicationContract.persistSceneValue, Name(record.id), Name($0.name), $0.value)
            }
        }
    }

    /// How many keys the open scenes have waiting.
    var pendingSaves: Int {
        _list.storage.value.reduce(0) { $0 + $1.pending }
    }

    /// The application as the root of a message: one node per open scene.
    func tree(of application: Application) -> Node {
        // One scene value per scene: a scene's `@State` boxes are its value's own.
        Node(
            contract: ApplicationContract.self,
            children: list.map { SceneElement(record: $0, scene: application.scene).body })
    }
}

/// A scene as the tree holds it - a composed view, so each open scene has `@State`
/// of its own, paired under its number.
struct SceneElement: Element {
    /// Which scene.
    let record: SceneRecord

    /// What the application says a scene is.
    let scene: Scene

    var body: Node {
        let authored = SceneElement.unwrapped(scene)

        var node = Node.composed(
            self, type: String(reflecting: type(of: authored)), scene: record
        ) { [record, scene] in
            SceneElement.build(record, scene)
        }

        node.id = record.id

        // What the application offered its scenes, and the scene's own session.
        node.environments = SceneElement.offered(by: scene)
            + [(key: ObjectIdentifier(SceneSession.self), object: record.session)]

        return node
    }

    /// The scene's node: its main window first, then the windows it has open
    /// beside it, and the reports the host makes about them.
    static func build(_ record: SceneRecord, _ scene: Scene) -> Node {
        let windows = scene.windows

        var declared: [WindowType: GroupShape] = [:]

        for group in windows.groups where declared[group.type] == nil {
            declared[group.type] = GroupShape(valueType: group.valueType, restore: group.restore)
        }

        record.declared = declared

        var main = windows.main.body(
            panel: { Inspector.panel(in: record) },
            session: record.windowSession(SceneElement.mainKey))
        main.id = SceneElement.mainKey

        var children = [main]

        // Read here, so this scene is what builds again when a window opens in it.
        for opened in record.windows {
            guard let group = windows.groups.first(where: { $0.type == opened.type }) else {
                continue
            }

            var window = group.make(opened, record).body(
                panel: nil, session: record.windowSession(opened.key))
            window.id = opened.key

            // Written either way, so none of them is ever cleared off a window.
            // Design: docs/design/core/scenes.md#opening-windows
            window.write(WindowContract.windowType, opened.type)
            window.describe(WindowContract.windowValue, opened.text)
            window.write(WindowContract.hidesWhenInactive, group.hides)
            window.write(WindowContract.floatsOnTop, group.floats)

            children.append(window)
        }

        // A window that closed takes its session with it.
        record.keepWindowSessions()

        var node = Node(contract: SceneContract.self, children: children)
        node.environments = windows.environments

        // The user closed a window of the scene - its key is the payload.
        node.addHandler(SceneContract.windowClosed.token) {
            if let key = EventBuffer.current.value()?.string {
                record.closed(key: key)
            }
        }

        // The system restored one: its kind and its value's text. A render is asked for
        // either way - the host holds the window until it hears.
        node.addHandler(SceneContract.windowRestored.token) {
            if let name = EventBuffer.current.value(0)?.string {
                record.restored(kind: name, text: EventBuffer.current.value(1)?.string)
            }

            Renderer.shared.setNeedsRender()
        }

        // Its main window has gone - the user closed it - and the scene with it.
        node.addHandler(SceneContract.destroying.token) { Scenes.shared.ended(record) }

        // Where the scene stands, as the host sees it.
        node.addHandler(SceneContract.activated.token) { record.session.phase = .active }
        node.addHandler(SceneContract.deactivated.token) { record.session.phase = .inactive }
        node.addHandler(SceneContract.stopped.token) { record.session.phase = .background }

        return node
    }

    /// What the tree knows a scene's main window by.
    static let mainKey = "main"

    /// The scene the application wrote, under whatever it offered it.
    static func unwrapped(_ scene: Scene) -> Scene {
        (scene as? OfferingScene).map { unwrapped($0.base) } ?? scene
    }

    /// What `.environment(_:)` offered the scene, outermost first - so the one
    /// written last is nearest, the way it is on a view.
    static func offered(by scene: Scene) -> [(key: ObjectIdentifier, object: AnyObject)] {
        guard let offering = scene as? OfferingScene else { return [] }

        return offered(by: offering.base) + [(key: offering.key, object: offering.object)]
    }
}

/// A state box a scene may keep - one declared with a `SceneKey`, which the
/// differ hands the scene it is built in.
protocol SceneClaiming: AnyObject {
    /// Pairs the box with the scene it is in: the storage the scene keeps
    /// under its key, and where its writes are kept.
    func claimScene(_ record: SceneRecord)
}
