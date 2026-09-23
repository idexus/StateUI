// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A scene as the tree holds it, and the node its build answers: the main window,
// the windows open beside it, and the handlers of the host's reports.
// Design: docs/design/core/scenes.md#the-scene-tree

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
