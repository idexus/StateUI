// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The application as it runs: where it stands, what its controls look like,
/// how its values animate, what it keeps between launches, and opening its
/// windows.
///
///     @Environment(\.application) private var application
///
///     Button("New window").onClicked(policy: .ignoreWhileRunning) { try await application.openWindow() }
///     Button("Inspector").onClicked(policy: .ignoreWhileRunning) { try await application.openWindow(.inspector) }
///
/// A session is one opening of something declared: the application from its
/// start to the end of its process, a scene from its first window opening to
/// its last closing, a window from `.created` to `.destroying`. Each is in the
/// environment of everything under it - `\.application`, `\.scene`,
/// `\.window` - so a view acts on the one it is in, from a handler, an
/// engine or a task alike.
///
/// Design: docs/design/types/sessions.md#one-opening-of-something-declared
@MainActor
public final class ApplicationSession {
    /// Where the application stands: in front, behind another application, or
    /// out of sight, as the host maps its native application and window
    /// lifecycle.
    public internal(set) var phase: SessionPhase {
        get { _phase }
        set { _phase = newValue }
    }

    @State private var _phase: SessionPhase = .active

    /// What the application is, as the host describes it: its name, identifier, version and build, and the theme
    /// in force - the one `application.colorScheme` holds, else the one the system asks for - updated live.
    public let info = ApplicationInfo()

    /// The sessions of the scenes standing right now, in the order they
    /// opened - read like any state, so a view that shows them is built again
    /// as a scene opens or ends.
    ///
    ///     Text("\(application.scenes.count) open")
    public var scenes: [SceneSession] { OpenScenes.shared.list.map(\.session) }

    /// The theme the application shows in: nil - the default - follows the
    /// user's setting, `.light` and `.dark` hold it whatever the system asks.
    ///
    ///     application.colorScheme = .dark
    ///     Picker([nil, .light, .dark], selection: application.$colorScheme) { $0.map { "\($0)" } ?? "As the system" }
    ///
    /// The host shows every window in it, natively, and reports the theme in
    /// force as `info.colorScheme`, which color pairs resolve against.
    @State public var colorScheme: ColorScheme? = nil

    /// The theme last handed to the host.
    private var sentColorScheme: ColorScheme?

    /// The application's own accent, which its controls and `Color.accent`
    /// take where the user chooses none for the system - the Web, iOS and
    /// iPadOS, GNOME before 47; where the user chose one - macOS, Windows,
    /// Android, GNOME 47 on - the user's stands. nil keeps the platform's.
    ///
    ///     application.accentColor = Color(hex: 0x4CC2FF)
    ///
    /// The host reports the accent in force as `info.accentColor`; a pair
    /// follows the theme.
    @State public var accentColor: Color? = nil

    /// The accent last handed to the host.
    private var sentAccentColor: Color?

    /// Hands the host the accent the application holds, its half in force where it is a pair: again as the theme
    /// turns.
    func sendAccentColor() {
        tellAct(ApplicationContract.useAccentColor, sentAccentColor.flatMap { Color(propValue: $0.propValue.resolvingTheme()) })
    }

    /// The theme in force turned: an accent of two halves is handed on again.
    func themeTurned() {
        if sentAccentColor?.propValue.isThemed == true { sendAccentColor() }
    }

    /// The styles every control in the application can be given.
    ///
    ///     init() {
    ///         application.styles = StyleSheet {
    ///             Style<Text>().fontSize(14)
    ///         }
    ///     }
    ///
    /// A style resolves into the controls it applies to, and a color pair in
    /// it follows the theme. A sheet written again is the next render's.
    @State public var styles: StyleSheet? = nil

    /// How every value in the application animates when it changes.
    ///
    ///     application.motion = .spring(response: .milliseconds(260))
    ///
    /// A color animates to its new color, a view that grew to its new size.
    /// `.none` turns animation off everywhere, for an application that draws
    /// its own. A view overrides it with `.motion(_:)`, a state with
    /// `@State(motion:)`, and one write with `$state.journey.snap(to:)` or
    /// `$state.journey.move(to:_:)`.
    @State public var motion: Motion = .standard

    /// A fresh instance, for providing a fake to one branch with
    /// `.environment(...)`. It opens scenes as the application's own does.
    public init() {
        // Whoever writes them - the application, a control the binding is handed to - the host is told.
        // Design: docs/design/core/state.md#bindings
        _colorScheme.storage.keep = { [weak self] scheme in
            guard let self, scheme != self.sentColorScheme else { return }
            self.sentColorScheme = scheme
            tellAct(ApplicationContract.useColorScheme, scheme)
        }
        _accentColor.storage.keep = { [weak self] accent in
            guard let self, accent != self.sentAccentColor else { return }
            self.sentAccentColor = accent
            self.sendAccentColor()
        }
    }

    /// Opens one more window of the `WindowGroup` with no name - what launch
    /// opens and *File ▸ New Window* does - in its scene, which opens with it
    /// where it does not stand.
    ///
    /// - Throws: `WindowError.unsupported` where the platform opens no second
    ///   window - a phone.
    public func openWindow() async throws {
        try OpenScenes.shared.open(nil)
    }

    /// Opens a window of `type` in the scene declaring it, which opens with it
    /// where it does not stand: the one window of a `Window(type)`, or one more
    /// of a `WindowGroup(type)`.
    ///
    ///     Button("Inspector").onClicked(policy: .ignoreWhileRunning) { try await application.openWindow(.inspector) }
    ///
    /// - Throws: `WindowError.alreadyOpen` where its one window is open,
    ///   `WindowError.undeclared` where no scene declares it, and
    ///   `WindowError.unsupported` where the platform opens no second window - a
    ///   phone.
    public func openWindow(_ kind: WindowKind<Void>) async throws {
        try OpenScenes.shared.open(kind.key)
    }

    /// Opens the window of `kind` for `value` in the scene declaring it, which
    /// opens with it where it does not stand.
    ///
    ///     Button("Open").onClicked(policy: .ignoreWhileRunning) { try await application.openWindow(.document, value: id) }
    ///
    /// - Throws: `WindowError.alreadyOpen` where a window for that value is
    ///   open, and the rest of `WindowError` where it cannot open.
    public func openWindow<Value: Codable & Hashable>(
        _ kind: WindowKind<Value>,
        value: Value
    ) async throws {
        try OpenScenes.shared.open(kind.key, value: AnyHashable(value), text: try ValueText.write(value), of: Value.self)
    }

    /// Closes the window of `kind` - every window of a `WindowGroup(kind)` -
    /// its scene ending with its last window.
    ///
    /// - Throws: `WindowError.notOpen` where none is open, and
    ///   `WindowError.undeclared` where no scene declares it.
    public func closeWindow(_ kind: WindowKind<Void>) async throws {
        try OpenScenes.shared.close(kind.key)
    }

    /// Closes the window of `kind` for `value`, its scene ending with its last
    /// window.
    ///
    /// - Throws: `WindowError.notOpen` where no window for that value is open,
    ///   and the rest of `WindowError` where it cannot close.
    public func closeWindow<Value: Codable & Hashable>(
        _ kind: WindowKind<Value>,
        value: Value
    ) async throws {
        try OpenScenes.shared.close(kind.key, value: AnyHashable(value), of: Value.self)
    }

    /// Forgets what an application wrote - what a registration starts from, so
    /// a second one inherits none of the first one's styles or keys.
    func forget() {
        styles = nil
        motion = .standard
    }
}
