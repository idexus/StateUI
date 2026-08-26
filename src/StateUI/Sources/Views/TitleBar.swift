// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// MAUI: TitleBar.

/// TitleBar's own properties - the half a `Style<TitleBar>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol TitleBarProperties: PropertyContainer {}

extension TitleBarProperties {
    /// A second line beside the title, drawn dimmer - where a window says which
    /// document or section it is showing. MAUI: TitleBar.Subtitle.
    public func subtitle(_ value: String) -> Modified {
        setValue(.subtitle, .string(value))
    }

    /// A small image before the title - a file in the app's Resources/Images,
    /// by the name MAUI gives it once built. MAUI: TitleBar.Icon.
    public func icon(_ value: ImageSource) -> Modified {
        setValue(.icon, value.propValue)
    }

    /// The colour the title and subtitle are drawn in. MAUI:
    /// TitleBar.ForegroundColor - the bar behind them is `.backgroundColor`,
    /// which every view already has.
    public func foregroundColor(_ value: Color) -> Modified {
        setValue(.foregroundColor, value.propValue)
    }
}

/// The window's own strip of chrome, in place of the system title bar -
/// desktop only. MAUI: TitleBar, set as `Window.TitleBar`.
///
///     struct MainWindow: Window {
///         var titleBar: TitleBar? {
///             TitleBar("StateUI Gallery")
///                 .subtitle("Fundamentals")
///                 .trailingContent {
///                     Button("Surprise me")
///                 }
///         }
///
///         var content: Page { HomePage() }
///     }
///
/// Where it draws at all was measured against MAUI 10.0.20's metadata:
/// `WindowHandler.MapTitleBar` has a body on Mac Catalyst and Windows and
/// nowhere else, so a phone and a tablet ignore the whole thing - in MAUI as
/// here. `@Environment var device: DeviceInfo` is how an application asks
/// which kind of device it is on while the tree is being built.
///
/// Three slots take views: `leadingContent`, `content` and `trailingContent`.
/// A view in a slot is there to be USED, so the renderer registers each as one
/// of MAUI's passthrough elements - it takes the click, and the rest of the
/// bar goes on dragging the window.
///
/// Each slot is written the way every other nested content in this library is,
/// so an `if` and a `ForEach` work inside one and are IDENTIFIED there - which
/// branch was taken is part of the path the differ matches on, exactly as it is
/// inside a `VStack`. A slot whose closure produces nothing is EMPTIED:
///
///     TitleBar("Notes")
///         .trailingContent {
///             if showsAccount {
///                 ImageButton("account.png")
///             }
///         }
///
/// MAUI's slot holds ONE view, so a closure that produces several fills it with
/// the first - put a layout in for more, the way a `Border`'s content is
/// written.
public struct TitleBar: View, TitleBarProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<TitleBar>` is written against.
    public init() {
        node = Node(type: .titleBar)
    }

    /// A bar reading `title` - usually the application's name. MAUI:
    /// TitleBar.Title.
    public init(_ title: String) {
        node = Node(type: .titleBar, props: [.title: .string(title)])
    }

    // MARK: Properties

    // MARK: The slots

    /// A view before the title - a back button, a sidebar toggle.
    /// MAUI: TitleBar.LeadingContent.
    ///
    ///     TitleBar("Notes")
    ///         .leadingContent {
    ///             ImageButton("menu.png").onClicked { showsPane.toggle() }
    ///         }
    ///
    /// A closure producing nothing empties the slot, which is what an `if` in
    /// one is for.
    public func leadingContent(@ViewBuilder _ content: () -> [Element]) -> Self {
        slot(.leadingContent, content())
    }

    /// A view in the middle of the bar, where an application-wide search box
    /// goes. MAUI: TitleBar.Content.
    ///
    ///     TitleBar("Notes")
    ///         .content {
    ///             SearchBar($query).widthRequest(320)
    ///         }
    ///
    /// A closure producing nothing empties the slot.
    public func content(@ViewBuilder _ content: () -> [Element]) -> Self {
        slot(.content, content())
    }

    /// A view at the far end - an account button, a settings gear.
    /// MAUI: TitleBar.TrailingContent.
    ///
    /// A closure producing nothing empties the slot.
    public func trailingContent(@ViewBuilder _ content: () -> [Element]) -> Self {
        slot(.trailingContent, content())
    }

    /// Puts a view into a named slot, replacing what was there. The slot a
    /// `.contextFlyout` appended stays LAST, the rule every slot-carrying
    /// list follows.
    ///
    /// Nothing to put means NO WRAPPER NODE, which is how the slot is emptied:
    /// the host reads a slot's leaving as its wrapper's absence from an
    /// arranged list, and a wrapper that arrived with no children is a PATCH
    /// about a slot whose view did not change. The two would be one message
    /// otherwise, and the reading that keeps a patch working is the one that
    /// leaves a toggled-off button in the chrome.
    private func slot(_ type: NodeType, _ views: [Element]) -> Self {
        var copy = self
        copy.node.children.removeAll { $0.type == type }
        let slots = copy.node.children.filter { $0.type == .contextFlyout }
        copy.node.children.removeAll { $0.type == .contextFlyout }

        let filled = views.isEmpty ? [] : [Node(type: type, children: views.map { $0.body })]

        copy.node.children += filled + slots
        return copy
    }
}
