// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A scene's windows as its `body` declares them, in the order written. What `SceneBuilder` makes of a scene's body;
/// nobody writes one.
public struct Windows: Scene {
    /// Each declaration, in the order written.
    let declared: [DeclaredWindows]

    /// None: the library's own scene.
    public var body: Never { return fatalError("Windows is the library's own scene: it has no body") }
}

extension Windows {
    /// The declaration of `type`'s windows - nil for the group launch and *File ▸ New Window* make a window of.
    func declaration(of type: WindowType?) -> DeclaredWindows? {
        declared.first { $0.type == type }
    }

    /// What a window of this scene opens as where none is named: the group with no name, else the first declaration
    /// of windows of no value.
    var opening: DeclaredWindows? {
        declaration(of: nil) ?? declared.first { $0.valueType == nil }
    }
}
