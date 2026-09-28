// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One kind of window a scene opens beside its main one: one window of it,
/// or - given `for:` - one per value.
///
///     WindowGroup(.fonts) { FontsWindow() }
///     WindowGroup(.document, for: UUID.self) { $id in DocumentWindow(id: id) }
///
/// The group says what the window is; the scene's session says when it opens:
///
///     @Environment private var scene: SceneSession
///
///     Button("Fonts").onClicked { try await scene.openWindow(.fonts) }
///     Button("Open").onClicked { try await scene.openWindow(.document, value: id) }
///
/// A window of a group belongs to its scene: it closes with the scene, and the
/// platform restores it to its scene for the same value, which is why the
/// value is `Codable`. A host without independent windows refuses
/// `openWindow` with `WindowError.unsupported`.
public struct WindowGroup {
    /// The kind of window.
    let type: WindowType

    /// The type of value the group opens one window per; nil for one window.
    let valueType: Any.Type?

    /// The window for one that is open, in the scene that has it open.
    let make: (_ opened: OpenedWindow, _ record: SceneRecord) -> Window

    /// A value read back from its text: what a restored window is opened for.
    let restore: (_ text: String) -> AnyHashable?

    /// Whether its windows hide while another scene is in front.
    var hides = false

    /// Whether its windows float above the application's other windows.
    var floats = false

    /// A group that opens one window, in any scene that declares it.
    ///
    ///     WindowGroup(.debugInspector) { DebugInspector() }
    ///
    /// - Parameters:
    ///   - type: what a session's `openWindow` opens it by.
    ///   - window: the window.
    public init(_ type: WindowType, @WindowBuilder window: @escaping () -> Window) {
        self.type = type
        valueType = nil
        make = { _, _ in window() }
        restore = { _ in nil }
    }

    /// A group that opens one window per value - a document per document, an
    /// inspector per item.
    ///
    ///     WindowGroup(.document, for: UUID.self) { $id in DocumentWindow(id: id) }
    ///
    /// The window is handed a binding to its own value: reading it says which
    /// value the window is for, and writing it makes the same window about
    /// another - which is also what the system restores it for.
    ///
    /// - Parameters:
    ///   - type: what a session's `openWindow` opens one by.
    ///   - value: the type of value one window stands for - anything
    ///     `Codable` and `Hashable`, so the platform can write it down.
    ///   - window: the window for one value.
    public init<Value: Codable & Hashable & SendableMetatype>(
        _ type: WindowType,
        for value: Value.Type,
        @WindowBuilder window: @escaping (Binding<Value>) -> Window
    ) {
        self.type = type
        valueType = Value.self
        make = { opened, record in
            // The value the scene was built with; a write retargets this window,
            // and the scene, which reads what it has open, builds it again.
            let standing = opened.value?.base as! Value

            let binding = Binding<Value>(
                get: { standing },
                set: { record.retarget(opened.serial, to: $0) })

            return window(binding)
        }
        restore = { text in ValueText.read(Value.self, from: text).map(AnyHashable.init) }
    }

    /// Whether the group's windows hide while another scene of the
    /// application is the one in front - and come back when their own is.
    /// A host without that native policy leaves the windows visible.
    ///
    ///     WindowGroup(.fonts) { FontsWindow() }
    ///         .hidesWhenInactive(true)
    public func hidesWhenInactive(_ hides: Bool) -> WindowGroup {
        var copy = self
        copy.hides = hides
        return copy
    }

    /// Whether the group's windows float above the application's other
    /// windows - a tool that stays in sight over the main window it serves -
    /// while the application is in front. A host without native window levels
    /// leaves their order to the platform.
    ///
    ///     WindowGroup(.fonts) { FontsWindow() }
    ///         .floatsOnTop(true)
    public func floatsOnTop(_ floats: Bool) -> WindowGroup {
        var copy = self
        copy.floats = floats
        return copy
    }
}
