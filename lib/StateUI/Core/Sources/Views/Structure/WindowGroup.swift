// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A factory of windows, each showing one view, made as they are asked for - in the scene that declares it, which
/// opens with its first window and stands while one is open. With no name, what launch and *File ▸ New* make one
/// more of, one such group in an application; with a name, a window each time `application.openWindow(.kind)` asks;
/// with a name and `for:`, one window per value.
///
///     WindowGroup { MainPage() }
///     WindowGroup(.editor) { EditorPage() }
///     WindowGroup(.document, for: UUID.self) { $id in DocumentPage(id: id) }
///
/// One window of a kind in its scene is a `Window`.
public struct WindowGroup: Scene {
    /// What it makes.
    var declared: DeclaredWindows

    /// None: the library's own scene.
    public var body: Never { return fatalError("a WindowGroup is the library's own scene: it has no body") }

    /// The group launch and *File ▸ New* make a window of, showing `content` - an `if`/`else` there swaps what a
    /// window shows.
    ///
    /// - Parameter content: the view a window shows.
    public init<Content: View>(@ViewBuilder content: @escaping () -> Content) {
        declared = DeclaredWindows(
            type: nil, valueType: nil, kind: String(reflecting: Content.self),
            page: { _, _ in Node.page(content()) })
    }

    /// Windows of a kind, one more each time it is asked for, showing `content`.
    ///
    ///     WindowGroup(.editor) { EditorPage() }
    ///
    ///     Button("New editor").onClicked { try await application.openWindow(.editor) }
    ///
    /// - Parameters:
    ///   - type: what `ApplicationSession.openWindow` opens one by, and what the platform restores one as.
    ///   - content: the view a window shows.
    public init<Content: View>(_ type: WindowType, @ViewBuilder content: @escaping () -> Content) {
        declared = DeclaredWindows(
            type: type, valueType: nil, kind: String(reflecting: Content.self),
            page: { _, _ in Node.page(content()) })
    }

    /// One window per value - a document per document, an inspector per item.
    ///
    ///     WindowGroup(.document, for: UUID.self) { $id in DocumentPage(id: id) }
    ///
    /// The view is handed a binding to its window's value: reading it says which value the window is for, and
    /// writing it makes the same window about another - which is also what the system restores it for.
    ///
    /// - Parameters:
    ///   - type: what `ApplicationSession.openWindow` opens one by.
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

    /// Offers an object to everything in its windows, resolved by type the way `.environment` on a view is.
    ///
    ///     WindowGroup { MainPage() }
    ///         .environment(nav)
    public func environment<Value: AnyObject>(_ object: Value) -> Self {
        var copy = self
        copy.declared.environments.append((key: ObjectIdentifier(Value.self), object: object))
        return copy
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
