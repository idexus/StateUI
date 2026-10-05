// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The Web's part of the acts every host performs (`HostActPerformer`): the clock and the zones as the browser has
/// them, a word to the screen reader through the page's live region, the focus, and a value kept in the browser's
/// storage for the page's site.
/// Design: docs/design/platforms/web/runtime.md#acts
@MainActor
final class WebActToolkit: ActToolkit {
    private unowned let renderer: WebRenderer

    init(renderer: WebRenderer) {
        self.renderer = renderer
    }

    let host = "Web"

    func localTime() -> (hour: Int, minute: Int, second: Int, millisecond: Int) {
        WebRelay.localTime
    }

    func localZone() -> String {
        WebRelay.localZone
    }

    func utcOffset(of zone: String?, on day: CalendarDate?) -> Int? {
        WebRelay.utcOffset(of: zone, on: day)
    }

    /// The page asks nothing of the user yet.
    func show(_ question: HostQuestion, answered: @escaping (Bool, String?) -> Void) -> Bool {
        false
    }

    func announce(_ words: String) {
        WebRelay.announce(words)
    }

    func hideOnScreenKeyboard() -> Bool {
        WebRelay.blurField()
    }

    func focus(_ element: MountedElement) -> Bool? {
        guard let view = (element.native as? WebElement)?.view else { return nil }
        return WebRelay.focus(view.node)
    }

    func unfocus(_ element: MountedElement) -> Bool {
        guard let view = (element.native as? WebElement)?.view else { return false }
        WebRelay.unfocus(view.node)
        return true
    }

    func keep(_ call: HostActCall) -> Bool {
        guard call.act == .persistValue else { return false }
        WebKeptValues.keep(call, core: renderer.runtime.core, application: renderer.applicationName)
        return true
    }

    func performOwn(_ call: HostActCall) -> Bool {
        false
    }

    func performRegistered(_ call: HostActCall) -> Bool {
        false
    }

    func log(_ message: String) {
        WebRenderer.log.error(message)
    }
}
