// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
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

    /// One of the visible page's actions.
    struct Action: Equatable {
        var title: String
        var picture: String?
        var overflows: Bool
        var isEnabled: Bool
    }

    /// What the bar says and shows.
    struct Content: Equatable {
        var title = ""
        var background: HostValue?
        var foreground: HostValue?
        var navigation = Navigation.none
        var actions: [Action] = []
    }

    /// What the navigation button does when the user presses it.
    var onNavigation: (() -> Void)?

    /// What the bar does when the user picks one of its actions, handed its place among them.
    var onAction: ((Int) -> Void)?

    private(set) var content = Content()
    private var shown = false

    init() {
        super.init { number in
            Java.new(JavaAPI.bar, JavaAPI.newBar, .object(AndroidRenderer.context), .long(number))
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
        if previous?.actions != content.actions {
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

    private func showActions(_ actions: [Action]) {
        Java.frame {
            let titles = Java.array(of: JavaAPI.string, actions.map { Java.string($0.title) })
            let bitmaps = actions.map { $0.picture.flatMap(AndroidPictures.bitmap(named:)) }
            let pictures = Java.array(of: JavaAPI.bitmap, bitmaps.map { $0?.reference })
            let overflows = Java.booleans(actions.map(\.overflows))
            let enabled = Java.booleans(actions.map(\.isEnabled))
            withExtendedLifetime(bitmaps) {
                Java.call(
                    reference, JavaAPI.setBarActions,
                    .object(titles), .object(pictures), .object(overflows), .object(enabled))
            }
        }
    }

    /// The user pressed the navigation button.
    override func clicked() {
        onNavigation?()
    }

    override func detach() {
        super.detach()
        onNavigation = nil
        onAction = nil
    }
}
