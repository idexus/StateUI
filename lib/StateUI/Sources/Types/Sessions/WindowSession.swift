// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A window as it runs: its lifecycle, title, requested geometry, chrome,
/// presented pages, and close operation.
///
///     @Environment private var window: WindowSession
///
///     VStack { … }
///         .onCreated {
///             window.title = "Gallery"
///             window.width = 1100
///             window.height = 800
///         }
///         .onChanged(window.phase) {
///             if window.phase == .stopped { try await save() }
///         }
///
///     Button("Close").onClicked { try await window.close() }
///
/// Every window offers its own, so a view acts on the window it is in, and
/// what the window is told stands until it is told otherwise. See
/// `ApplicationSession` for what a session is.
///
/// Geometry is a request to a host that exposes movable or resizable windows.
/// Each axis is independent: changing width does not restore an old height,
/// and changing x does not restore an old y. A `nil` axis stays under native
/// window management, including platform restoration and the user's resizing.
/// Full-screen hosts may retain these values without presenting geometry.
public final class WindowSession {
    /// Where the window stands in its life right now. Starts `.created`.
    @State public internal(set) var phase: WindowPhase = .created

    /// What the window is called in native window chrome and system surfaces.
    @State public var title: String? = nil

    /// The horizontal position of the outer frame's top-left corner in the
    /// host's desktop coordinate space, where the platform lets an
    /// application place its windows.
    @State public var x: Double? = nil

    /// The vertical position of the outer frame's top-left corner in the
    /// host's desktop coordinate space, where the platform lets an
    /// application place its windows.
    @State public var y: Double? = nil

    /// The requested width of the window's content area.
    ///
    /// A size, not a fixed one: the user can still resize the window within
    /// whatever minimum and maximum it was given. For a size that cannot be
    /// changed, say so - a maximum equal to the minimum.
    @State public var width: Double? = nil

    /// The requested height of the window's content area.
    @State public var height: Double? = nil

    /// The minimum width of the window's content area.
    @State public var minimumWidth: Double? = nil

    /// The minimum height of the window's content area.
    @State public var minimumHeight: Double? = nil

    /// The maximum width of the window's content area.
    /// A smaller value than `minimumWidth` is treated as `minimumWidth`.
    @State public var maximumWidth: Double? = nil

    /// The maximum height of the window's content area.
    /// A smaller value than `minimumHeight` is treated as `minimumHeight`.
    @State public var maximumHeight: Double? = nil

    /// Whether the user may maximize the window through the platform's own
    /// ways of doing so, where the platform lets an application say.
    @State public var isMaximizable: Bool? = nil

    /// Whether the user may minimize the window through the platform's own
    /// ways of doing so, where the platform lets an application say.
    @State public var isMinimizable: Bool? = nil

    /// Whether the desktop shows through the window, blurred - under whatever
    /// its pages leave uncovered or paint in a colour that lets it through,
    /// such as a background with an alpha or the margin around a floating
    /// sidebar.
    ///
    ///     window.isTranslucent = true
    ///
    /// A desktop host lays its windows' own material under the pages; a host
    /// whose windows cannot show what is behind them keeps them opaque, and
    /// the application's colours read as they are written. `nil` keeps the
    /// platform's opaque window.
    @State public var isTranslucent: Bool? = nil

    /// Authored window chrome presented by hosts that support a custom title
    /// area.
    ///
    ///     .onCreated {
    ///         if device.formFactor == .desktop {
    ///             window.titleBar = TitleBar("Notes").trailingContent { AccountButton() }
    ///         }
    ///     }
    ///
    /// A view in one of the bar's slots is built where the bar is shown, and
    /// follows its own state.
    @State public var titleBar: TitleBar? = nil

    /// The pages presented over the window, with the last page on top.
    ///
    ///     @State private var sheets: [Sheet] = []
    ///
    ///     .onCreated {
    ///         window.modalStack = ModalStack($sheets) { sheet in
    ///             switch sheet {
    ///             case .settings: SettingsPage(sheets: $sheets)
    ///             case .about: AboutPage()
    ///             }
    ///         }
    ///     }
    ///
    /// Written once: the stack reads the array as the window is built, so
    /// presenting a page is `sheets.append(.settings)`, dismissing one is a
    /// `remove`, and a sheet the user drags away truncates the array itself.
    /// It belongs to the window rather than to any individual page. See
    /// `ModalStack`.
    @State public var modalStack: ModalStack? = nil

    /// The key the tree knows the window by in its scene.
    let key: String

    /// The scene the window is in - nothing for the one a view outside every
    /// window reads, and nothing once that scene has ended.
    weak var record: SceneRecord?

    /// A window's own, made by the scene it is in.
    init(key: String, record: SceneRecord?) {
        self.key = key
        self.record = record
    }

    /// A fresh instance, for providing a fake to one branch with
    /// `.environment(...)` - one that closes nothing.
    public convenience init() {
        self.init(key: "", record: nil)
    }

    /// Closes the window - and where it is its scene's main window, the scene
    /// with every window of it.
    ///
    /// - Throws: `WindowError.noScene` for a window of no open scene - one
    ///   whose scene has ended included, whoever still holds it -
    ///   `WindowError.notOpen` for one already closed, and
    ///   `WindowError.unsupported` where the host cannot close this window
    ///   independently.
    public nonisolated(nonsending) func close() async throws {
        guard let record, Scenes.shared.record(id: record.id) === record else {
            throw WindowError.noScene
        }

        if key == SceneElement.mainKey {
            try Scenes.shared.close(record)
        } else {
            try record.closeWindow(key: key)
        }
    }

    /// The explicitly authored window properties. An absent value leaves that
    /// capability under native window management.
    var props: [Prop: PropValue] {
        var props: [Prop: PropValue] = [:]

        props.describe(WindowContract.title, title)
        props.describe(WindowContract.x, x)
        props.describe(WindowContract.y, y)
        props.describe(WindowContract.width, width)
        props.describe(WindowContract.height, height)
        props.describe(WindowContract.isMaximizable, isMaximizable)
        props.describe(WindowContract.isMinimizable, isMinimizable)
        props.describe(WindowContract.isTranslucent, isTranslucent)
        props.describe(WindowContract.minimumWidth, minimumWidth)
        props.describe(WindowContract.minimumHeight, minimumHeight)
        props.describe(WindowContract.maximumWidth, maximumWidth)
        props.describe(WindowContract.maximumHeight, maximumHeight)

        return props
    }

    /// What hangs off the window besides its page: the chrome and the modal
    /// stack, each as the node the host knows it by - built as the window is,
    /// so the modal stack reads its array there.
    var slots: [Node] {
        var slots: [Node] = []

        if let bar = titleBar { slots.append(bar.body) }
        if let stack = modalStack { slots.append(stack.node) }

        return slots
    }
}
