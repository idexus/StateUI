// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What each render costs and what it builds, shown inside the application.
///
///     @Environment(\.window) private var window
///
///     VStack { … }
///         .toolbar { ToolbarButton.debugInspector(window) }
///
/// A window shows its scene's inspector where `window.debugInspector` says, and
/// hides it with nil.
///
/// Each render is listed as it happens - its cause, its road, the time Swift
/// took to describe it and the host to apply it, and how many composed views
/// it built and carried - and a chosen render shows its tree of composed
/// views with each one's time. It also lists what the library complained of:
/// a value it could not use, a write it refused.
///
/// Each scene has its own. It opens along the bottom of the window its ⓘ is
/// in, folded to one line, the last render - the ⓘ of another window of the
/// scene moves it there; opened out, it can dock at the side on a desktop or a
/// tablet, or show in the scene's own window where the scene declares one:
///
///     Window(.debugInspector) { DebugInspector() }
///
/// Nothing is recorded while every inspector is closed or paused.
///
/// `DebugInspector()` is that window's view, showing the renders that reached
/// its scene - opened by a docked inspector's "Open in a window", or by
/// `application.openWindow(.debugInspector)`. Where a scene declares none, or
/// the platform opens no second window, the inspector docks in a window of
/// the scene instead.
public struct DebugInspector: View {
    /// The scene it inspects - the one it is a window of.
    @Environment(\.scene) private var scene

    /// The inspector's window.
    public init() {}

    /// The inspector, for its scene.
    public var body: some View { InspectorPage(scene: scene.id) }
}

extension DebugInspector {
    /// Where an inspector shows.
    public enum Place: Sendable, Equatable {
        /// Along the bottom of the window it docks in, the page going on above
        /// it - where the ⓘ opens it, folded to one line.
        case bottom

        /// Down the trailing side of the window it docks in, under the bar.
        case side

        /// In the scene's `DebugInspector` window - where the scene declares
        /// one and the platform opens windows, and docked everywhere else.
        case window
    }
}
