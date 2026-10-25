// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A factory of windows, each showing one view, made as they are asked for - in the scene that declares it, which
/// opens with its first window and stands while one is open. With no name, what launch and *File ▸ New Window* make
/// one more of, one such group in an application; with a name, a window each time `application.openWindow(.kind)`
/// asks; with a name and `for:`, one window per value - the kind's.
///
///     WindowGroup { MainPage() }
///     WindowGroup(.editor) { EditorPage() }
///     WindowGroup(.document) { $id in DocumentPage(id: id) }
///
/// One window of a kind in its scene is a `Window`.
public struct WindowGroup: Scene {
    /// What it makes.
    var declared: DeclaredWindows

    /// None: the library's own scene.
    public var body: Never { return fatalError("a WindowGroup is the library's own scene: it has no body") }

    /// The group launch and *File ▸ New Window* make a window of, showing `content` - an `if`/`else` there swaps
    /// what a window shows.
    ///
    /// - Parameter content: the view a window shows.
    public init<Content: View>(@ViewBuilder content: @escaping () -> Content) {
        declared = DeclaredWindows(
            type: nil, valueType: nil,
            page: { _, _ in Node.page(content()) })
    }

    /// Windows of a kind, one more each time it is asked for, showing `content`.
    ///
    ///     WindowGroup(.editor) { EditorPage() }
    ///
    ///     Button("New editor").onClicked(.ignoreWhileRunning) { try await application.openWindow(.editor) }
    ///
    /// - Parameters:
    ///   - type: what `ApplicationSession.openWindow` opens one by, and what the platform restores one as.
    ///   - content: the view a window shows.
    public init<Content: View>(_ type: WindowType<Void>, @ViewBuilder content: @escaping () -> Content) {
        declared = DeclaredWindows(
            type: type.key, valueType: nil,
            page: { _, _ in Node.page(content()) })
    }

    /// One window per value of the kind - a document per document, an inspector per item.
    ///
    ///     extension WindowType where Value == UUID { static let document = WindowType("document") }
    ///
    ///     WindowGroup(.document) { $id in DocumentPage(id: id) }
    ///
    /// The view is handed a binding to its window's value: reading it says which value the window is for, and
    /// writing it makes the same window about another - which is also what the system restores it for.
    ///
    /// - Parameters:
    ///   - type: what `ApplicationSession.openWindow` opens one by, with a value of its type - anything `Codable`
    ///     and `Hashable`, so the platform can write it down.
    ///   - content: the view for one value.
    public init<Value: Codable & Hashable & SendableMetatype, Content: View>(
        _ type: WindowType<Value>,
        @ViewBuilder content: @escaping (Binding<Value>) -> Content
    ) {
        declared = DeclaredWindows(
            type: type.key, valueType: Value.self,
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

    /// Runs when the application is asked to open a link - one the user chose elsewhere, of a scheme the
    /// application's head registers - and the platform gives it to one of these windows: its address.
    ///
    ///     WindowGroup { NotesPage(path: $path) }
    ///         .onLinkOpened { address in path = Route.path(for: address) }
    ///
    /// It runs with the scene's state, whichever of the windows hears it.
    public func onLinkOpened(_ handler: @escaping @MainActor (String) throws -> Void) -> Self {
        var copy = self
        copy.declared.links.append { $0.addHandler(WindowContract.linkOpened, handler) }
        return copy
    }

    /// The same, with a handler that awaits: its `policy` says what a link does when it comes again while a run
    /// is under way.
    public func onLinkOpened(_ policy: GatePolicy, _ handler: @escaping ValueEventHandler<String>) -> Self {
        var copy = self
        copy.declared.links.append { $0.addHandler(WindowContract.linkOpened, policy: policy, handler) }
        return copy
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onLinkOpened(gate: Gate, _ handler: @escaping ValueEventHandler<String>) -> Self {
        var copy = self
        copy.declared.links.append { $0.addHandler(WindowContract.linkOpened, gate: gate, handler) }
        return copy
    }
}
