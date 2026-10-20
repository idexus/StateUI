// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@_spi(Host) import StateUIApple

/// UIKit's part of the acts every host performs (`HostActPerformer`): the clock and the zones, a question as an
/// alert over what the user's window shows, a word to VoiceOver, the keyboard's focus, a value kept.
/// Design: docs/design/platforms/uikit/runtime.md#acts
@MainActor
final class UIKitActToolkit: ActToolkit {
    private unowned let renderer: UIKitRenderer

    /// The question showing now, where one is.
    private(set) var showing: UIKitQuestion?

    /// What the host told VoiceOver, in order, where a test asked for it with `[]`; nil keeps nothing.
    var announcedForTesting: [String]?

    init(renderer: UIKitRenderer) {
        self.renderer = renderer
    }

    let host = "UIKit"

    func localTime() -> (hour: Int, minute: Int, second: Int, millisecond: Int) {
        let now = Calendar.current.dateComponents([.hour, .minute, .second, .nanosecond], from: Date())
        return (now.hour ?? 0, now.minute ?? 0, now.second ?? 0, (now.nanosecond ?? 0) / 1_000_000)
    }

    func localZone() -> String {
        TimeZone.current.identifier
    }

    func utcOffset(of name: String?, on day: CalendarDate?) -> Int? {
        guard let zone = name.map(TimeZone.init(identifier:)) ?? TimeZone.current else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let date = day.flatMap {
            calendar.date(from: DateComponents(year: $0.year, month: $0.month, day: $0.day, hour: 12))
        } ?? Date()
        return zone.secondsFromGMT(for: date) / 60
    }

    /// Asks in UIKit's alert over what the window asked shows - its top sheet, else its pages - once nothing moves.
    func show(
        _ question: HostQuestion, over window: MountedElement?,
        answered: @escaping (Result<HostQuestion.Given, ActFailure>) -> Void
    ) -> MountedElement? {
        guard let root = renderer.root(asked: window), let window = root.view.window.flatMap(renderer.element(of:))
        else { return nil }
        let asked = UIKitQuestion(question)
        showing = asked
        asked.ask(in: root) { [weak self] given in
            self?.showing = nil
            answered(.success(given))
        }
        return window
    }

    func announce(_ words: String) {
        announcedForTesting?.append(words)
        UIAccessibility.post(notification: .announcement, argument: words)
    }

    /// Shows every window in `theme`: each window's own style, unspecified for the system's.
    func useColorScheme(_ theme: ColorScheme) {
        for (_, controller) in renderer.roster.windows {
            controller.window?.overrideUserInterfaceStyle = Self.style(theme)
        }
    }

    /// UIKit's style for `theme`.
    static func style(_ theme: ColorScheme) -> UIUserInterfaceStyle {
        switch theme {
        case .light: .light
        case .dark: .dark
        case .system: .unspecified
        }
    }

    /// Takes the keyboard down: whatever holds the focus in the window asked gives it up; whether anything did.
    func hideOnScreenKeyboard(in window: MountedElement?) -> Bool {
        guard let window = renderer.window(asked: window), Self.holder(in: window) != nil else { return false }
        return window.endEditing(true)
    }

    func focus(_ element: MountedElement) -> Bool? {
        guard let view = (element.native as? UIKitElement)?.view else { return nil }
        guard let focusable = Self.focusable(in: view) else { return false }
        // Not every view that takes the focus says so: the elements hear it moved.
        defer { renderer.focusMoved() }
        return focusable.becomeFirstResponder()
    }

    func unfocus(_ element: MountedElement) -> Bool {
        guard let view = (element.native as? UIKitElement)?.view else { return false }
        Self.holder(in: view)?.resignFirstResponder()
        renderer.focusMoved()
        return true
    }

    func keep(_ call: HostActCall) -> Bool {
        switch call.act {
        case .persistValue: renderer.savePersistent(call)
        case .persistSceneValue: renderer.keepSceneValue(call)
        default: return false
        }
        return true
    }

    /// A web view's own acts: stepping back or forward, loading again, running a script - which answers once the
    /// page has run it; an ItemsView's scroll to an item; and a map's slide to a region.
    func performOwn(_ call: HostActCall) -> Bool {
        guard [.goBack, .goForward, .reload, .evaluateJavaScript, .scrollTo, .moveToRegion].contains(call.act) else {
            return false
        }
        let core = CoreLink()
        let element: MountedElement
        do {
            element = try renderer.runtime.tree.aimed(call)
        } catch {
            core.fail(call, error.reason, log: { UIKitRenderer.log.error($0) })
            return true
        }
        if call.act == .scrollTo {
            guard let items = (element.native as? UIKitElement)?.view as? UIKitItemsView else {
                core.fail(call, "scrollTo is an act of an ItemsView", log: { UIKitRenderer.log.error($0) })
                return true
            }
            items.scroll(
                to: call.arguments.value(1)?.string ?? "",
                anchor: call.arguments.value(2).flatMap(ScrollAnchor.init(propValue:)) ?? .nearest)
            core.reply(call, [])
            return true
        }
        if call.act == .moveToRegion {
            guard let map = (element.native as? UIKitElement)?.view as? MapKitView else {
                core.fail(call, "moveToRegion is an act of a Map", log: { UIKitRenderer.log.error($0) })
                return true
            }
            guard let region = call.arguments.value(1).flatMap(MapRegion.init(propValue:)) else {
                core.fail(call, "moveToRegion was given no region", log: { UIKitRenderer.log.error($0) })
                return true
            }
            map.show(region, sliding: true)
            core.reply(call, [])
            return true
        }
        guard let web = (element.native as? UIKitElement)?.view as? WebKitView else {
            core.fail(call, "\(call.act.name) is an act of a web view", log: { UIKitRenderer.log.error($0) })
            return true
        }
        web.perform(call, through: core)
        return true
    }

    /// The application's own acts, registered through `StateUIActs`.
    func performRegistered(_ call: HostActCall) -> Bool {
        UIKitInterop.acts.perform(
            call, in: renderer.runtime.tree, core: CoreLink(), view: { ($0.native as? UIKitElement)?.view },
            log: { UIKitRenderer.log.error($0) })
    }

    func log(_ message: String) {
        UIKitRenderer.log.error(message)
    }

    /// The view that takes the focus for `view`: it, or the first view in it that can.
    private static func focusable(in view: UIView) -> UIView? {
        if view.canBecomeFirstResponder { return view }
        for child in view.subviews { if let found = focusable(in: child) { return found } }
        return nil
    }

    /// The view holding the focus in `view`, where one does.
    private static func holder(in view: UIView) -> UIView? {
        if view.isFirstResponder { return view }
        for child in view.subviews { if let found = holder(in: child) { return found } }
        return nil
    }
}
#endif
