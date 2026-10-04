// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An application's scenes as its `body` declares them, in the order written. What `ApplicationBuilder` makes of an
/// application's body; nobody writes one.
public struct Scenes: Scene {
    /// Each scene, in the order written.
    let declared: [any Scene]

    /// None: the library's own scene.
    public var body: Never { return fatalError("Scenes is the library's own scene: it has no body") }
}

extension Scenes {
    /// What an application's body declares: its scenes, or the one scene a library test writes.
    static func of(_ body: any Scene) -> Scenes {
        body as? Scenes ?? Scenes(declared: [body])
    }

    /// Each scene's windows, read without making anything a reader: what a scene declares is fixed.
    /// Design: docs/design/core/scenes.md#a-scene-stands-once
    var windows: [Windows] {
        ReadScope.collect { declared.map(\.declaredWindows) }.value
    }

    /// Where the scene declaring windows of `type` stands - the group with no name for nil - the first where several
    /// do; nil where none does.
    func index(declaring type: WindowType?) -> Int? {
        windows.firstIndex { $0.declaration(of: type) != nil }
    }

    /// Where the scene launch opens a window of stands: the one declaring the group with no name, else the first.
    var launching: Int {
        index(declaring: nil) ?? 0
    }
}
