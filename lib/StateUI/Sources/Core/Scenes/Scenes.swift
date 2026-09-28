// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The scenes an application has open, and the tree the host keeps its platform
// windows in step with.
// Design: docs/design/core/scenes.md#the-scene-tree

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
