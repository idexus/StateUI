// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Windows made as they are asked for, each showing one view. Without `for:`, a scene's main window - one per
/// session, the platform making as many sessions as the user asks for - with no name for the kind *File ▸ New*
/// opens, or naming a kind of its own; with a name and `for:`, one window per value, opened beside the main one.
///
///     WindowGroup { MainPage() }
///     WindowGroup(.editor) { EditorPage() }
///     WindowGroup(.document, for: UUID.self) { $id in DocumentPage(id: id) }
///
/// One window of a kind beside the main one is a `Window`. A window opened beside the main one belongs to its
/// scene: it opens through the scene's session, closes with the scene, and the platform restores it to its scene
/// for the same value, which is why the value is `Codable`.
public struct WindowGroup<Role>: Scene {
    /// What it makes.
    var declared: DeclaredWindows

    /// None: the library's own scene.
    public var body: Never { return fatalError("a WindowGroup is the library's own scene: it has no body") }

    /// Offers an object to everything in its windows, resolved by type the way `.environment` on a view is.
    ///
    ///     WindowGroup { MainPage() }
    ///         .environment(nav)
    public func environment<Value: AnyObject>(_ object: Value) -> Self {
        var copy = self
        copy.declared.environments.append((key: ObjectIdentifier(Value.self), object: object))
        return copy
    }
}

extension WindowGroup where Role == WindowRole.Main {
    /// The scene's main window, showing `content` - an `if`/`else` there swaps what the one window shows. Its
    /// scene is the kind *File ▸ New* opens.
    ///
    /// - Parameter content: the view the window shows.
    public init<Content: View>(@ViewBuilder content: @escaping () -> Content) {
        declared = DeclaredWindows(
            type: nil, valueType: nil, kind: String(reflecting: Content.self),
            page: { _, _ in Node.page(content()) })
    }

    /// The main window of a kind of scene of its own, showing `content`: each session one more, opened by the
    /// application's session.
    ///
    ///     WindowGroup(.editor) { EditorPage() }
    ///
    ///     Button("New editor").onClicked { try await application.openWindow(.editor) }
    ///
    /// - Parameters:
    ///   - type: the scene's kind - what `ApplicationSession.openWindow` opens one by, and what the platform
    ///     restores the scene as.
    ///   - content: the view the window shows.
    public init<Content: View>(_ type: WindowType, @ViewBuilder content: @escaping () -> Content) {
        declared = DeclaredWindows(
            type: type, valueType: nil, kind: String(reflecting: Content.self),
            page: { _, _ in Node.page(content()) })
    }
}

extension WindowGroup where Role == WindowRole.Beside {
    /// One window per value, opened beside the main one - a document per document, an inspector per item.
    ///
    ///     WindowGroup(.document, for: UUID.self) { $id in DocumentPage(id: id) }
    ///
    /// The view is handed a binding to its window's value: reading it says which value the window is for, and
    /// writing it makes the same window about another - which is also what the system restores it for.
    ///
    /// - Parameters:
    ///   - type: what a session's `openWindow` opens one by.
    ///   - value: the type of value one window stands for - anything `Codable` and `Hashable`, so the platform
    ///     can write it down.
    ///   - content: the view for one value.
    public init<Value: Codable & Hashable & SendableMetatype, Content: View>(
        _ type: WindowType,
        for value: Value.Type,
        @ViewBuilder content: @escaping (Binding<Value>) -> Content
    ) {
        declared = DeclaredWindows(
            type: type, valueType: Value.self, kind: String(reflecting: Content.self),
            page: { opened, record in
                // The value the scene was built with; a write retargets this window, and the scene, which reads
                // what it has open, builds it again.
                let standing = opened?.value?.base as! Value

                let binding = Binding<Value>(
                    get: { standing },
                    set: { if let opened, let record { record.retarget(opened.serial, to: $0) } })

                return Node.page(content(binding))
            },
            restore: { text in ValueText.read(Value.self, from: text).map(AnyHashable.init) })
    }

    /// Whether the group's windows hide while another scene of the application is the one in front - and come
    /// back when their own is. A host without that native policy leaves the windows visible.
    public func hidesWhenInactive(_ hides: Bool) -> Self {
        var copy = self
        copy.declared.hides = hides
        return copy
    }

    /// Whether the group's windows float above the application's other windows while the application is in
    /// front. A host without native window levels leaves their order to the platform.
    public func floatsOnTop(_ floats: Bool) -> Self {
        var copy = self
        copy.declared.floats = floats
        return copy
    }
}
