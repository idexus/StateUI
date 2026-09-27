// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// AppKit's part of the acts every host performs (`HostActPerformer`): the clock and the zones, a question as an
/// alert on the window the user is looking at, a word to VoiceOver, the keyboard's focus, a value kept.
///
/// THE FOCUS IS THE PLATFORM'S: the host asks the window who holds it and never mirrors that identity as state.
/// `hideOnScreenKeyboard` takes the focus off whatever holds it in the window the user is looking at, answering
/// whether anything did.
/// Design: docs/design/host/runtime.md#acts
@MainActor
final class AppKitActToolkit: ActToolkit {
    private unowned let renderer: AppKitRenderer

    /// The question showing now, where one is.
    private(set) var showing: AppKitQuestion?

    /// What the host told the screen reader, in order.
    private(set) var announcedForTesting: [String] = []

    init(renderer: AppKitRenderer) {
        self.renderer = renderer
    }

    let host = "AppKit"

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

    /// Asks in AppKit's alert, a sheet on the window the user is looking at.
    /// Design: docs/design/host/runtime.md#questions-for-the-user
    func show(_ question: HostQuestion, answered: @escaping (Bool, String?) -> Void) -> Bool {
        guard let window = renderer.userWindow else { return false }
        let asked = AppKitQuestion(question, in: window)
        showing = asked
        asked.ask(presenting: renderer.presentsWindows) { [weak self] accepted, words in
            self?.showing = nil
            answered(accepted, words)
        }
        return true
    }

    /// Tells the screen reader `words`, now, over whatever it was saying.
    func announce(_ words: String) {
        announcedForTesting.append(words)
        NSAccessibility.post(
            element: renderer.userWindow ?? NSApp as Any, notification: .announcementRequested,
            userInfo: [.announcement: words, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    /// Takes the focus off whatever holds it in the window the user is looking at; whether anything did.
    func hideOnScreenKeyboard() -> Bool {
        guard let window = renderer.userWindow,
              let holder = window.firstResponder as? NSView,
              holder !== window.contentView
        else { return false }

        return window.makeFirstResponder(nil)
    }

    func focus(_ element: MountedElement) -> Bool? {
        guard let view = (element.native as? AppKitElement)?.view else { return nil }
        guard let window = view.window, let focusable = AppKitFocus.focusable(in: view) else { return false }
        return window.makeFirstResponder(focusable)
    }

    func unfocus(_ element: MountedElement) -> Bool {
        guard let view = (element.native as? AppKitElement)?.view else { return false }
        if let window = view.window, AppKitFocus.holds(view, window.firstResponder) { window.makeFirstResponder(nil) }
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

    func performOwn(_ call: HostActCall) -> Bool {
        false
    }

    func performRegistered(_ call: HostActCall) -> Bool {
        AppKitInterop.acts.perform(
            call, in: renderer.runtime.tree, core: CoreLink(), view: { ($0.native as? AppKitElement)?.view },
            log: { AppKitRenderer.log.error($0) })
    }

    func log(_ message: String) {
        AppKitRenderer.log.error(message)
    }
}
#endif
