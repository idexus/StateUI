// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The application as it runs: where it stands, what its controls look like,
/// how its values animate, what it keeps between launches, and opening another
/// of its scenes.
///
///     @Environment private var application: ApplicationSession
///
///     Button("New window").onClicked { try await application.openScene() }
///
/// A session is one opening of something declared: the application from its
/// start to the end of its process, a scene from its main window opening to
/// its closing, a window from `.created` to `.destroying`, a content page for
/// as long as its element lives. Each is in the environment of everything
/// under it - `ApplicationSession`, `SceneSession`, `WindowSession`,
/// `PageSession` - so a view acts on the one it is in, from a handler, an
/// engine or a task alike.
///
/// Design: docs/design/types/sessions.md#one-opening-of-something-declared
public final class ApplicationSession {
    /// Where the application stands: in front, behind another application, or
    /// out of sight, as the host maps its native application and window
    /// lifecycle.
    @State public internal(set) var phase: ApplicationPhase = .active

    /// The sessions of the scenes open right now, in the order they opened -
    /// read like any state, so a view that shows them is built again as a
    /// scene opens or closes.
    ///
    ///     Label("\(application.scenes.count) open")
    public var scenes: [SceneSession] { Scenes.shared.list.map(\.session) }

    /// The styles every control in the application can be given.
    ///
    ///     init() {
    ///         application.styles = StyleSheet {
    ///             Style<Label>().fontSize(14)
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

    /// Where the kept state lives: the platform's preferences, or a store the
    /// application registered on the host side with `StateUIStores.Add`.
    /// Written in `init` with the keys.
    @State public var persistentStorage: PersistentStorage = .preferences

    /// A fresh instance, for providing a fake to one branch with
    /// `.environment(...)`. It opens scenes as the application's own does.
    public init() {}

    /// Opens another session of the application: a new scene, its main window
    /// first - what *File ▸ New Window* does, asked from the interface.
    ///
    /// - Throws: `WindowError.unsupported` where the platform opens no second
    ///   window - a phone.
    public nonisolated(nonsending) func openScene() async throws {
        try Scenes.shared.openScene()
    }

    /// Forgets what an application wrote - what a registration starts from, so
    /// a second one inherits none of the first one's styles or keys.
    func forget() {
        styles = nil
        motion = .standard
        persistentKeys = []
        persistentStorage = .preferences
    }
}
