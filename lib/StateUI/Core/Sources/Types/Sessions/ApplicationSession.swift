// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The application as it runs: where it stands, what its controls look like,
/// how its values animate, what it keeps between launches, and opening its
/// windows.
///
///     @Environment(\.application) private var application
///
///     Button("New window").onClicked { try await application.openWindow() }
///     Button("Inspector").onClicked { try await application.openWindow(.inspector) }
///
/// A session is one opening of something declared: the application from its
/// start to the end of its process, a scene from its first window opening to
/// its last closing, a window from `.created` to `.destroying`. Each is in the
/// environment of everything under it - `\.application`, `\.scene`,
/// `\.window` - so a view acts on the one it is in, from a handler, an
/// engine or a task alike.
///
/// Design: docs/design/types/sessions.md#one-opening-of-something-declared
public final class ApplicationSession {
    /// Where the application stands: in front, behind another application, or
    /// out of sight, as the host maps its native application and window
    /// lifecycle.
    @State public internal(set) var phase: ApplicationPhase = .active

    /// What the application is, as the host describes it: its name, identifier, version and build, and the theme
    /// the system asks for.
    public let info = AppInfo()

    /// The sessions of the scenes standing right now, in the order they
    /// opened - read like any state, so a view that shows them is built again
    /// as a scene opens or ends.
    ///
    ///     Text("\(application.scenes.count) open")
    public var scenes: [SceneSession] { OpenScenes.shared.list.map(\.session) }

    /// The styles every control in the application can be given.
    ///
    ///     init() {
    ///         application.styles = StyleSheet {
    ///             Style<Text>().fontSize(14)
    ///         }
    ///     }
    ///
    /// A style resolves into the controls it applies to, and a colour pair in
    /// it follows the theme. A sheet written again is the next render's.
    @State public var styles: StyleSheet? = nil

    /// How every value in the application animates when it changes.
    ///
    ///     application.motion = .spring(response: 260)
    ///
    /// A colour animates to its new colour, a view that grew to its new size.
    /// `.none` turns animation off everywhere, for an application that draws
    /// its own. A view overrides it with `.motion(_:)`, a state with
    /// `@State(motion:)`, and one write with `$state.journey.snap(to:)` or
    /// `$state.journey.move(to:_:)`.
    @State public var motion: Motion = .standard

    /// Every key the application keeps between launches. Write it in the
    /// application's `init`: the host reads exactly these keys from the store
    /// before the first view is built.
    ///
    ///     init() {
    ///         application.persistentKeys = [.lastGroup, .appearance]
    ///     }
    ///
    /// **A key left off this list is never read.** State declared with it
    /// still saves, so its value arrives one launch late.
    ///
    /// Design: docs/design/types/sessions.md#kept-keys-are-declared
    @State public var persistentKeys: [PersistentKey] = []

    /// A fresh instance, for providing a fake to one branch with
    /// `.environment(...)`. It opens scenes as the application's own does.
    public init() {}

    /// Opens one more window of the `WindowGroup` with no name - what launch
    /// opens and *File ▸ New Window* does - in its scene, which opens with it
    /// where it does not stand.
    ///
    /// - Throws: `WindowError.unsupported` where the platform opens no second
    ///   window - a phone.
    public nonisolated(nonsending) func openWindow() async throws {
        try OpenScenes.shared.open(nil)
    }

    /// Opens a window of `type` in the scene declaring it, which opens with it
    /// where it does not stand: the one window of a `Window(type)`, or one more
    /// of a `WindowGroup(type)`.
    ///
    ///     Button("Inspector").onClicked { try await application.openWindow(.inspector) }
    ///
    /// - Throws: `WindowError.alreadyOpen` where its one window is open,
    ///   `WindowError.undeclared(type)` where no scene declares it,
    ///   `WindowError.wrongValue(type)` where it opens one per value, and
    ///   `WindowError.unsupported` where the platform opens no second window - a
    ///   phone.
    public nonisolated(nonsending) func openWindow(_ type: WindowType) async throws {
        try OpenScenes.shared.open(type)
    }

    /// Opens the window of `type` for `value` in the scene declaring it, which
    /// opens with it where it does not stand.
    ///
    ///     Button("Open").onClicked { try await application.openWindow(.document, value: id) }
    ///
    /// - Throws: `WindowError.alreadyOpen` where a window for that value is
    ///   open, and the rest of `WindowError` where it cannot open.
    public nonisolated(nonsending) func openWindow<Value: Codable & Hashable>(
        _ type: WindowType,
        value: Value
    ) async throws {
        try OpenScenes.shared.open(type, value: AnyHashable(value), text: try ValueText.write(value), of: Value.self)
    }

    /// Closes the window of `type` - every window of a `WindowGroup(type)` -
    /// its scene ending with its last window.
    ///
    /// - Throws: `WindowError.notOpen` where none is open, and
    ///   `WindowError.undeclared(type)` where no scene declares it.
    public nonisolated(nonsending) func closeWindow(_ type: WindowType) async throws {
        try OpenScenes.shared.close(type)
    }

    /// Closes the window of `type` for `value`, its scene ending with its last
    /// window.
    ///
    /// - Throws: `WindowError.notOpen` where no window for that value is open,
    ///   and the rest of `WindowError` where it cannot close.
    public nonisolated(nonsending) func closeWindow<Value: Codable & Hashable>(
        _ type: WindowType,
        value: Value
    ) async throws {
        try OpenScenes.shared.close(type, value: AnyHashable(value), of: Value.self)
    }

    /// Forgets what an application wrote - what a registration starts from, so
    /// a second one inherits none of the first one's styles or keys.
    func forget() {
        styles = nil
        motion = .standard
        persistentKeys = []
    }
}
