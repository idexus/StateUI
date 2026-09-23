// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A scene's windows: its main window, and the groups of windows it may open
/// beside it.
///
///     Windows {
///         WindowGroup(.fonts) { FontsWindow() }
///     } main: {
///         if loading { LoadingWindow() } else { MainWindow() }
///     }
///
/// The main window is the scene on screen: it opens with the scene, and the
/// user closing it ends the scene and every window of its groups. It is one
/// window whatever type it is written as - the `if` above changes what that
/// window shows.
public struct Windows {
    /// The kinds of window the scene may open beside its main one.
    let groups: [WindowGroup]

    /// The main window.
    let main: Window

    /// What `.environment(_:)` offered every window of the scene.
    var environments: [(key: ObjectIdentifier, object: AnyObject)] = []

    /// A main window, and the groups of windows the scene may open beside it.
    ///
    /// - Parameters:
    ///   - groups: one `WindowGroup` per kind of window, and an `if` for a kind
    ///     only some scenes declare.
    ///   - main: the main window - an `if` choosing between two is allowed,
    ///     and swaps what the one window shows.
    public init(
        @WindowGroupBuilder _ groups: () -> [WindowGroup],
        @WindowBuilder main: () -> Window
    ) {
        self.groups = groups()
        self.main = main()
    }

    /// A main window and nothing to open beside it.
    ///
    /// - Parameter main: the main window.
    public init(@WindowBuilder main: () -> Window) {
        self.init({}, main: main)
    }

    /// Offers an object to every window of the scene, resolved by type the way
    /// `.environment` on a view is - how a session's windows share one context:
    ///
    ///     @State private var nav = Navigation()
    ///
    ///     var windows: Windows {
    ///         Windows { … } main: { MainWindow() }
    ///             .environment(nav)
    ///     }
    public func environment<Value: AnyObject>(_ object: Value) -> Windows {
        var copy = self
        copy.environments.append((key: ObjectIdentifier(Value.self), object: object))
        return copy
    }
}
