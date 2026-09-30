// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// A navigation stack's bar: Android's own toolbar, the host's `StateUIBar`.
/// Design: docs/design/platforms/android/pages.md#the-bar
@MainActor
final class AndroidBarView: AndroidView {
    /// What the navigation button does.
    enum Navigation: Equatable {
        case none
        case back
        /// The sidebar's picture, or none to show the platform's own.
        case sidebar(String?)
    }

    /// What the bar says and shows.
    struct Content: Equatable {
        var title = ""
        var background: HostValue?
        var foreground: HostValue?
        var navigation = Navigation.none
        var actions: [AndroidMenu.Item] = []
    }

    /// What the navigation button does when the user presses it.
    var onNavigation: (() -> Void)?

    private(set) var content = Content()
    private var shown = false

    /// The view standing in for the title, where one does.
    private(set) weak var titleView: AndroidView?

    /// The theme the bar's actions take their words from: Android's overlay for a dark bar - light words - or a
    /// light one, by the host layer's reading of the bar's colour (`BandWords.light`); the activity's where the tree
    /// paints no bar.
    /// Design: docs/design/platforms/android/pages.md#the-bar
    enum Words: Int32 {
        case platform = 0, light = 1, dark = 2

        /// The words a bar painted `background` takes.
        init(on background: HostValue?) {
            self = background.flatMap(BandWords.light(on:)).map { $0 ? .light : .dark } ?? .platform
        }
    }

    /// The theme the bar's actions take their words from, fixed as the bar is made.
    let words: Words

    init(words: Words = .platform) {
        self.words = words
        super.init { number in
            Java.new(JavaAPI.bar, JavaAPI.newBar, .object(AndroidRenderer.context), .long(number), .int(words.rawValue))
        }
    }

    /// Shows `content`, writing only the parts that changed.
    func show(_ content: Content) {
        let previous = shown ? self.content : nil
        shown = true
        self.content = content

        if previous?.title != content.title || previous?.background != content.background
            || previous?.foreground != content.foreground {
            let title = Java.string(content.title)
            Java.call(
                reference, JavaAPI.showBar, .object(title),
                .int(content.background.flatMap(Self.argb) ?? 0), .int(content.foreground.flatMap(Self.argb) ?? 0))
            Java.release(local: title)
        }
        if previous?.navigation != content.navigation || previous?.foreground != content.foreground {
            showNavigation(content.navigation, tint: content.foreground.flatMap(Self.argb) ?? 0)
        }
        if previous?.actions != content.actions || previous?.foreground != content.foreground {
            showActions(content.actions)
        }
    }

    private func showNavigation(_ navigation: Navigation, tint: Int32) {
        let (kind, picture, description): (Int32, String?, String) = switch navigation {
        case .none: (0, nil, "")
        case .back: (1, nil, "Back")
        case .sidebar(let picture): (2, picture, "Menu")
        }
        let bitmap = picture.flatMap(AndroidPictures.bitmap(named:))
        let words = Java.string(description)
        withExtendedLifetime(bitmap) {
            Java.call(
                reference, JavaAPI.setBarNavigation,
                .int(kind), .object(bitmap?.reference), .int(tint), .object(words))
        }
        Java.release(local: words)
    }

    /// The actions as the bar's menu, an item chosen reaching `onMenuChose` by its place among them.
    private func showActions(_ actions: [AndroidMenu.Item]) {
        AndroidMenu.encoded(actions.map(AndroidMenu.Entry.item)) { kinds, texts, pictures in
            Java.call(reference, JavaAPI.setBarActions, .object(kinds), .object(texts), .object(pictures))
        }
    }

    /// Shows `view` in place of the title - across the room between the navigation button and the actions -
    /// or the title again for nil.
    func showTitleView(_ view: AndroidView?) {
        guard view !== titleView else { return }
        titleView = view
        view?.forgetPlace()
        Java.call(reference, JavaAPI.setBarTitleView, .object(view?.reference))
    }

    /// The user pressed the navigation button.
    override func clicked() {
        onNavigation?()
    }

    override func detach() {
        super.detach()
        onNavigation = nil
    }
}
