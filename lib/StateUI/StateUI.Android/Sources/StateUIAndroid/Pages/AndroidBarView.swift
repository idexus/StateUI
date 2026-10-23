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
        case sidebar(HostPicture?)
        /// The sheet the stack stands in closing.
        case close
    }

    /// What the bar says and shows: its title, the line under it and the mark before them, its colors, its
    /// actions, and the page's menus behind its overflow.
    struct Content: Equatable {
        /// The title; nil where the page shows none, which leaves the bar's place for it empty.
        var title: String? = ""
        var subtitle: String?
        var mark: HostPicture?
        var background: HostValue?
        var foreground: HostValue?
        var navigation = Navigation.none
        /// What the button after the navigation button does: none, or the way back where the sidebar's toggle
        /// takes the navigation button.
        var afterNavigation = Navigation.none
        /// What the button at the bar's end does: none, or the sidebar's toggle.
        var endButton = Navigation.none
        var actions: [AndroidMenu.Item] = []
        var menus: [AndroidMenu.Entry] = []
    }

    /// What the navigation button does when the user presses it.
    var onNavigation: (() -> Void)?

    /// What the button after the navigation button does when the user presses it.
    var onAfterNavigation: (() -> Void)?

    /// What the button at the bar's end does when the user presses it.
    var onEndButton: (() -> Void)?

    /// The elements the bar's items stand for, in the order its menu numbers them: the actions, then the menus'
    /// items.
    var items: [MountedElement] = []

    private(set) var content = Content()
    private var shown = false

    /// The view standing in for the title, where one does.
    private(set) weak var titleView: AndroidView?

    /// The theme the bar's actions take their words from: Android's overlay for a dark bar - light words - or a
    /// light one, by the host layer's reading of the bar's color (`BandWords.light`); the activity's where the tree
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

    /// Shows `content`, writing only the parts that changed - every part on its first showing.
    func show(_ content: Content) {
        let previous = shown ? self.content : nil
        shown = true
        self.content = content
        func changed<Part: Equatable>(_ part: (Content) -> Part) -> Bool {
            previous.map { part($0) != part(content) } ?? true
        }
        let tint = content.foreground.flatMap(Self.argb) ?? 0

        if changed(\.title) || changed(\.subtitle) || changed(\.background) || changed(\.foreground) {
            let title = content.title.flatMap(Java.string)
            let subtitle = content.subtitle.flatMap(Java.string)
            Java.call(
                reference, JavaAPI.showBar, .object(title), .object(subtitle),
                .int(content.background.flatMap(Self.argb) ?? 0), .int(tint))
            Java.release(local: title)
            Java.release(local: subtitle)
        }
        if changed(\.navigation) || changed(\.foreground) { showNavigation(content.navigation, tint: tint) }
        if changed(\.afterNavigation) || changed(\.foreground) {
            showAfterNavigation(content.afterNavigation, tint: tint)
        }
        if changed(\.endButton) || changed(\.foreground) { showEndButton(content.endButton, tint: tint) }
        if changed(\.mark) {
            let bitmap = content.mark.flatMap(AndroidPictures.bitmap)
            withExtendedLifetime(bitmap) { Java.call(reference, JavaAPI.setBarMark, .object(bitmap?.reference)) }
        }
        if changed(\.actions) || changed(\.menus) || changed(\.foreground) {
            showActions(content.actions, menus: content.menus)
        }
    }

    private func showNavigation(_ navigation: Navigation, tint: Int32) {
        let said = CoreLink().chromeWords
        let (kind, picture, description): (AndroidBarNavigation, HostPicture?, String) = switch navigation {
        case .none: (.none, nil, "")
        case .back: (.back, nil, said.back)
        case .sidebar(let picture): (.sidebar, picture, said.sidebar)
        case .close: (.close, nil, said.close)
        }
        let bitmap = picture.flatMap(AndroidPictures.bitmap)
        let words = Java.string(description)
        withExtendedLifetime(bitmap) {
            Java.call(
                reference, JavaAPI.setBarNavigation,
                .int(kind.rawValue), .object(bitmap?.reference), .int(tint), .object(words))
        }
        Java.release(local: words)
    }

    /// The way back after the navigation button, or none.
    private func showAfterNavigation(_ button: Navigation, tint: Int32) {
        let said = CoreLink().chromeWords
        let (kind, description): (AndroidBarNavigation, String) = switch button {
        case .back: (.back, said.back)
        case .close: (.close, said.close)
        case .none, .sidebar: (.none, "")
        }
        let words = Java.string(description)
        Java.call(reference, JavaAPI.setBarAfterNavigation, .int(kind.rawValue), .int(tint), .object(words))
        Java.release(local: words)
    }

    /// The sidebar's toggle at the bar's end, in the sidebar's picture or the platform's glyph, or none.
    private func showEndButton(_ button: Navigation, tint: Int32) {
        guard case .sidebar(let picture) = button else {
            return Java.call(reference, JavaAPI.setBarEndToggle, .object(nil), .int(tint), .object(nil))
        }
        let bitmap = picture.flatMap(AndroidPictures.bitmap)
        let words = Java.string(CoreLink().chromeWords.sidebar)
        withExtendedLifetime(bitmap) {
            Java.call(reference, JavaAPI.setBarEndToggle, .object(bitmap?.reference), .int(tint), .object(words))
        }
        Java.release(local: words)
    }

    /// The actions as the bar's menu, each of the bar's groups a group of Android's menu, then the menus as its
    /// submenus behind the overflow, after a line where actions stand there too; an item chosen reaches
    /// `onMenuChose` by its place among the items.
    private func showActions(_ actions: [AndroidMenu.Item], menus: [AndroidMenu.Entry]) {
        let parted = !menus.isEmpty && actions.contains { !$0.onBar }
        let grouped = actions.enumerated().flatMap { place, action -> [AndroidMenu.Entry] in
            place > 0 && action.group != actions[place - 1].group ? [.separator, .item(action)] : [.item(action)]
        }
        let entries = grouped + (parted ? [.separator] : []) + menus
        AndroidMenu.encoded(entries) { kinds, texts, pictures in
            Java.call(reference, JavaAPI.setBarActions, .object(kinds), .object(texts), .object(pictures))
        }
    }

    /// The bar's own height for `width` points - unbounded where nil - in points.
    func height(width: Double?) -> Double {
        let widthSpec = width.map { ViewConstants.spec(ViewConstants.exactly, pixels($0)) } ?? ViewConstants.unspecified
        return Double(measure(width: widthSpec, height: ViewConstants.unspecified).height) / density
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

    /// The user pressed one of the bar's own buttons apart from its navigation button.
    override func chose(_ place: Int) {
        switch AndroidBarButton(rawValue: Int32(place)) {
        case .afterNavigation: onAfterNavigation?()
        case .atEnd: onEndButton?()
        case nil: break
        }
    }

    override func detach() {
        super.detach()
        onNavigation = nil
        onAfterNavigation = nil
        onEndButton = nil
        items = []
    }
}
