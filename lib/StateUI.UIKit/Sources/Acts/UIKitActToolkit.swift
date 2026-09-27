// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// UIKit's part of the acts every host performs (`HostActPerformer`): the clock and the zones, a question as an
/// alert over what the user's window shows, a word to VoiceOver, the keyboard's focus, a value kept.
/// Design: docs/design/platforms/uikit/runtime.md#acts
@MainActor
final class UIKitActToolkit: ActToolkit {
    private unowned let renderer: UIKitRenderer

    /// The question showing now, where one is.
    private(set) var showing: UIKitQuestion?

    /// What the host told VoiceOver, in order.
    private(set) var announcedForTesting: [String] = []

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

    /// Asks in UIKit's alert over what the user's window shows now - its top sheet, else its pages.
    func show(_ question: HostQuestion, answered: @escaping (Bool, String?) -> Void) -> Bool {
        guard var presenter = renderer.userWindow?.rootViewController else { return false }
        while let top = presenter.presentedViewController, !top.isBeingDismissed { presenter = top }
        let asked = UIKitQuestion(question)
        showing = asked
        asked.ask(over: presenter) { [weak self] accepted, words in
            self?.showing = nil
            answered(accepted, words)
        }
        return true
    }

    func announce(_ words: String) {
        announcedForTesting.append(words)
        UIAccessibility.post(notification: .announcement, argument: words)
    }

    /// Takes the keyboard down: whatever holds the focus in the user's window gives it up; whether anything did.
    func hideOnScreenKeyboard() -> Bool {
        guard let window = renderer.userWindow, Self.holder(in: window) != nil else { return false }
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
        guard call.act == .persistValue else { return false }
        renderer.savePersistent(call)
        return true
    }

    /// A web view's own acts: stepping back or forward, loading again, running a script - which answers once the
    /// page has run it.
    func performOwn(_ call: HostActCall) -> Bool {
        guard [.goBack, .goForward, .reload, .evaluateJavaScript].contains(call.act) else { return false }
        let core = CoreLink()
        let element: MountedElement
        do {
            element = try renderer.runtime.tree.aimed(call)
        } catch {
            core.fail(call, error.reason, log: { UIKitRenderer.log.error($0) })
            return true
        }
        guard let web = (element.native as? UIKitElement)?.view as? UIKitWebView else {
            core.fail(call, "\(call.act.name) is an act of a web view", log: { UIKitRenderer.log.error($0) })
            return true
        }
        switch call.act {
        case .goBack: web.step(.back)
        case .goForward: web.step(.forward)
        case .reload: web.step(.refresh)
        default:
            web.evaluate(call.arguments.value(1)?.string ?? "") { [weak renderer] answer in
                core.reply(call, [answer.propValue])
                renderer?.runtime.pump.turn()
            }
            return true
        }
        core.reply(call, [])
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
