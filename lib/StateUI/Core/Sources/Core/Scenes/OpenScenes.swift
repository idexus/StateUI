// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The application's scenes standing now, and the tree the host keeps its platform windows in step with.
// Design: docs/design/core/scenes.md#the-scene-tree

/// The application's scenes standing now - each at most once, from its first window to its last.
@MainActor
final class OpenScenes {
    /// The one there is: a process runs one application.
    static let shared = OpenScenes()

    /// The scenes standing, in the order they opened - a state the root reads, so a scene opening or ending builds
    /// the application again and no scene that stays.
    @State var list: [SceneRecord] = [OpenScenes.launch()]

    /// The number the next scene gets.
    private var next = 2

    /// The window launch opens, while it waits for the platform's first window.
    private var waiting: (record: SceneRecord, key: String)?

    /// The scene being built now, while the differ is inside one - what a `@State(sceneKey:)` made during the build
    /// claims from.
    var building: SceneRecord?

    private init() {
        waiting = (list[0], list[0].windows[0].key)
    }

    /// The scene launch opens, with its one window, settled once the application is made.
    private static func launch() -> SceneRecord {
        SceneRecord(id: "1", declaration: 0, windows: [OpenedWindow(type: nil, serial: 1, value: nil, text: nil)])
    }

    /// Starts again with the scene launch opens, waiting for the platform's first window - what an application is
    /// given as it registers.
    func reset() {
        let record = Self.launch()
        list = [record]
        next = 2
        waiting = (record, record.windows[0].key)
    }

    /// Settles the scene launch opens once the application is made, before anything reads it: the scene declaring the
    /// group with no name, else the first, and the window it opens.
    /// Design: docs/design/core/scenes.md#launch-and-new
    func settleLaunch(_ scenes: Scenes) {
        guard let (record, _) = waiting, list.count == 1, list[0] === record else { return }

        let index = scenes.launching
        guard let opening = scenes.windows[index].opening else {
            complain("the application declares no window launch can open: one with no value, or a WindowGroup with no name")
            return
        }

        record.declaration = index
        record.settle(OpenedWindow(type: opening.type, serial: 1, value: nil, text: nil))
        waiting = (record, record.windows[0].key)
    }

    /// The scene with a number, if it stands - read off the storage, so no build that asks becomes the list's reader.
    func record(id: String) -> SceneRecord? {
        _list.storage.value.first { $0.id == id }
    }

    /// Where a scene stands in the application's list - what the host's report about each scene's apply is ordered
    /// by.
    func index(of id: String) -> Int? {
        _list.storage.value.firstIndex { $0.id == id }
    }

    /// Whether the platform opens a window beside another: a desktop and an iPad do, a phone and a page in a browser
    /// do not, and a host that has not said does.
    static var opensWindows: Bool {
        let device = StandardEnvironment.device.info

        switch device.formFactor {
        case .desktop, .unknown: return device.platform != "Web"
        case .tablet: return device.platform == "iOS"
        default: return false
        }
    }

    /// What the application declares, made where it is not yet.
    private var scenes: Scenes? {
        Renderer.shared.madeApplication().map { Scenes.of($0.body) }
    }

    /// Whether `record`'s scene declares windows of `type`.
    func declares(_ type: WindowType, in record: SceneRecord) -> Bool {
        scenes.map { $0.windows[record.declaration].declaration(of: type) != nil } ?? false
    }

    /// The scene of declaration `index` standing now.
    private func standing(_ index: Int) -> SceneRecord? {
        _list.storage.value.first { $0.declaration == index }
    }

    /// The scene of declaration `index`: the one standing, or a new one, its kept `values` landing before its first
    /// build.
    private func scene(_ index: Int, restoring values: [String: PropValue]) -> SceneRecord {
        if let standing = standing(index) { return standing }

        let record = SceneRecord(id: "\(next)", declaration: index)
        next += 1
        record.restore(values)
        list.append(record)
        return record
    }

    // MARK: - Opening and closing windows

    /// Opens a window of `type` - nil for one more of the group launch and *File ▸ New Window* make a window
    /// of - for `value`, written `text`, in the scene declaring it, which opens with it where it does not stand.
    /// Design: docs/design/core/scenes.md#opening-windows
    func open(_ type: WindowType?, value: AnyHashable? = nil, text: String? = nil, of valueType: Any.Type? = nil)
        throws {
        guard Self.opensWindows else { throw WindowError.unsupported }
        guard let scenes else { throw WindowError.unsupported }

        let (index, declaration) = try Self.declaration(of: type, in: scenes)
        guard declaration.takes(valueType) else { throw WindowError.wrongValue(type ?? declaration.type!) }

        if let standing = standing(index), standing.holds(declaration, value: value) {
            throw WindowError.alreadyOpen
        }

        scene(index, restoring: [:]).open(declaration.type, value: value, text: text)
    }

    /// Closes the window of `type` for `value` - every window of a group of no value.
    func close(_ type: WindowType, value: AnyHashable? = nil, of valueType: Any.Type? = nil) throws {
        guard let scenes else { throw WindowError.notOpen }

        let (index, declaration) = try Self.declaration(of: type, in: scenes)
        guard declaration.takes(valueType) else { throw WindowError.wrongValue(type) }
        guard let record = standing(index) else { throw WindowError.notOpen }

        try record.close(type, value: value)
    }

    /// The scene declaring windows of `type` and the declaration - the window launch opens for nil.
    private static func declaration(of type: WindowType?, in scenes: Scenes) throws -> (Int, DeclaredWindows) {
        guard let type else {
            let index = scenes.launching
            guard let opening = scenes.windows[index].opening else { throw WindowError.unsupported }
            return (index, opening)
        }

        guard let index = scenes.index(declaring: type), let declared = scenes.windows[index].declaration(of: type)
        else { throw WindowError.undeclared(type) }

        return (index, declared)
    }

    // MARK: - What the platform hands over

    /// The platform handed over a window: its first, which the window launch opens takes; one it kept, of `type` and
    /// for the value written `text`, with its scene's kept `values`; or a new one of no kind. A kept window of a kind
    /// coming first takes the launch window's place; one refused leaves it waiting. Answers the number of the scene it opened in, nil where no scene
    /// declares it - the host closes that one.
    /// Design: docs/design/core/scenes.md#what-the-platform-hands-over
    func connected(_ type: WindowType?, text: String?, restoring values: [String: PropValue]) -> String? {
        guard let scenes else { return nil }

        if let (record, _) = waiting, type == nil, text == nil {
            waiting = nil
            record.restore(values)
            Renderer.shared.setNeedsRender()
            return record.id
        }

        guard let (index, declaration) = try? Self.declaration(of: type, in: scenes) else { return nil }

        var value: AnyHashable?
        if declaration.valueType != nil {
            guard let text, let read = declaration.restore(text) else { return nil }
            value = read
        } else if text != nil {
            return nil
        }

        if let (record, key) = waiting {
            waiting = nil
            record.remove(key, ending: false)
            if record.windows.isEmpty { list.removeAll { $0 === record } }
        }

        if let standing = standing(index), standing.holds(declaration, value: value) { return nil }

        let record = scene(index, restoring: values)
        record.open(declaration.type, value: value, text: text)

        // The host shows the window it is holding as soon as this returns.
        Renderer.shared.setNeedsRender()
        return record.id
    }

    /// A scene has ended: its last window went, or its session closed it.
    func ended(_ record: SceneRecord) {
        if waiting?.record === record { waiting = nil }
        list.removeAll { $0 === record }
        Inspector.ended(record)
    }

    // MARK: - What the scenes keep

    /// Every key the scenes standing have waiting, as the acts that keep them.
    func takeSaves() -> [ActCall] {
        _list.storage.value.flatMap { record in
            record.takeWaiting().map {
                ActCall(ApplicationContract.persistSceneValue, Name(record.id), Name($0.name), $0.value)
            }
        }
    }

    /// How many keys the scenes standing have waiting.
    var pendingSaves: Int {
        _list.storage.value.reduce(0) { $0 + $1.pending }
    }

    /// The application as the root of a message: one node per scene standing, each built from its declaration.
    func tree(of application: any Application) -> Node {
        // One scene value per scene: a scene's `@State` boxes are its value's own.
        Node(
            contract: ApplicationContract.self,
            children: list.map { record in
                let scenes = Scenes.of(application.body)
                return SceneElement(record: record, scene: scenes.declared[record.declaration]).node
            })
    }
}
