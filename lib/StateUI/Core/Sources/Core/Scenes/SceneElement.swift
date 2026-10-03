// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A scene as the tree holds it, and the node its build answers: its windows, and the
// handlers of the host's reports.
// Design: docs/design/core/scenes.md#the-scene-tree

/// A scene as the tree holds it - a composed view, so each open scene has `@State`
/// of its own, paired under its number.
struct SceneElement: Element {
    /// Which scene.
    let record: SceneRecord

    /// What the application says a scene is.
    let scene: any Scene

    var node: Node {
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

    /// The scene's node: its windows, in the order they opened, and the reports the host makes about them.
    static func build(_ record: SceneRecord, _ scene: any Scene) -> Node {
        let windows = scene.declaredWindows

        // Read here, so this scene is what builds again when a window of it opens or closes.
        var children: [Node] = []
        for (position, opened) in record.windows.enumerated() {
            guard let declaration = windows.declaration(of: opened.type) else { continue }

            var window = window(declaration, opened: opened, record, docks: position == 0)
            window.id = opened.key

            // Written either way, so none of them is ever cleared off a window.
            // Design: docs/design/core/scenes.md#opening-windows
            if let type = opened.type { window.write(WindowContract.windowType, type) }
            window.describe(WindowContract.windowValue, opened.text)
            window.write(WindowContract.hidesWhenInactive, declaration.hides)
            window.write(WindowContract.floatsOnTop, declaration.floats)

            children.append(window)
        }

        // A window that closed takes its session with it.
        record.keepWindowSessions()

        var node = Node(contract: SceneContract.self, children: children)

        // The user closed a window of the scene - its key is the payload; the scene ends with its last.
        node.addHandler(SceneContract.windowClosed.token) {
            if let key = EventBuffer.current.value()?.string {
                record.closed(key: key)
            }
        }

        // Where the scene stands, as the host sees it.
        node.addHandler(SceneContract.activated.token) { record.session.phase = .active }
        node.addHandler(SceneContract.deactivated.token) { record.session.phase = .inactive }
        node.addHandler(SceneContract.stopped.token) { record.session.phase = .background }

        return node
    }

    /// One window the scene has open, with what was offered it - the scene's inspector docked in it where `docks`
    /// says: its first.
    /// Design: docs/design/views/inspector.md#where-it-docks
    private static func window(
        _ declared: DeclaredWindows, opened: OpenedWindow, _ record: SceneRecord, docks: Bool
    ) -> Node {
        var node = Node.window(
            showing: { declared.page(opened, record) }, kind: declared.kind,
            session: record.windowSession(opened.key), inspector: docks ? { record.dockedInspector } : nil)
        node.environments.insert(contentsOf: declared.environments, at: 0)
        return node
    }

    /// The scene the application wrote, under whatever it offered it.
    static func unwrapped(_ scene: any Scene) -> any Scene {
        (scene as? any Offering).map { unwrapped($0.offered) } ?? scene
    }

    /// What `.environment(_:)` offered the scene, outermost first - so the one
    /// written last is nearest, the way it is on a view.
    static func offered(by scene: any Scene) -> [(key: ObjectIdentifier, object: AnyObject)] {
        guard let offering = scene as? any Offering else { return [] }

        return offered(by: offering.offered) + [(key: offering.key, object: offering.object)]
    }
}
