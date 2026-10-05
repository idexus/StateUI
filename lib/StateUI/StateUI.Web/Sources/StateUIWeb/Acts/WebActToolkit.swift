// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The Web's part of the acts every host performs (`HostActPerformer`): the clock and the zones as the browser has
/// them, a question in the browser's modal dialog, a word to the screen reader through the page's live region, the
/// focus, a value kept in the browser's storage for the page's site, a list scrolled to an item, and a web view's
/// steps and scripts.
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

    /// The question shown, held until the user answers it: the host layer shows one at a time.
    private var asking: WebQuestion?

    /// Design: docs/design/platforms/web/pages.md#questions-for-the-user
    func show(_ question: HostQuestion, answered: @escaping (Bool, String?) -> Void) -> Bool {
        let shown = WebQuestion(question) { [weak self] accepted, words in
            self?.asking = nil
            answered(accepted, words)
        }
        asking = shown
        shown.show()
        return true
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
        switch call.act {
        case .persistValue:
            WebKeptValues.keep(call, core: renderer.runtime.core, application: renderer.applicationName)
        case .persistSceneValue:
            let scenes = renderer.scenes
            if scenes.keep(call.arguments), let text = scenes.changed(root: renderer.runtime.tree.root) {
                WebKeptValues.writeScenes(text, application: renderer.applicationName)
            }
        default:
            return false
        }
        return true
    }

    /// An ItemsView's scroll to an item, and a web view's steps and scripts - which a document of another site takes
    /// none of.
    func performOwn(_ call: HostActCall) -> Bool {
        let owners: [Act: String] = [
            .scrollTo: "an ItemsView",
            .goBack: "a web view", .goForward: "a web view", .reload: "a web view", .evaluateJavaScript: "a web view",
        ]
        guard let owner = owners[call.act] else { return false }
        let core = renderer.runtime.core
        let elsewhere = "the page cannot reach into a document of another site"
        do {
            let element = try renderer.runtime.tree.aimed(call)
            switch (call.act, (element.native as? WebElement)?.view) {
            case (.scrollTo, let items as WebItemsView):
                items.scroll(
                    to: call.arguments.value(1)?.string ?? "",
                    anchor: call.arguments.value(2).flatMap(ScrollAnchor.init(propValue:)) ?? .nearest)
            case (.goBack, let frame as WebFrameView), (.goForward, let frame as WebFrameView),
                 (.reload, let frame as WebFrameView):
                let step: WebNavigationType = call.act == .goBack ? .back : call.act == .goForward ? .forward : .reload
                guard frame.step(step) else {
                    core.fail(call, elsewhere, log: log)
                    return true
                }
            case (.evaluateJavaScript, let frame as WebFrameView):
                let ran = frame.evaluate(call.arguments.value(1)?.string ?? "")
                guard ran.ran else {
                    core.fail(call, elsewhere, log: log)
                    return true
                }
                core.reply(call, [ran.answer.propValue])
                return true
            default:
                core.fail(call, "\(call.act.name) is an act of \(owner)", log: log)
                return true
            }
            core.reply(call, [])
        } catch {
            core.fail(call, error.reason, log: log)
        }
        return true
    }

    func performRegistered(_ call: HostActCall) -> Bool {
        WebInterop.acts.perform(
            call, in: renderer.runtime.tree, core: renderer.runtime.core, view: { ($0.native as? WebElement)?.view },
            log: log)
    }

    func log(_ message: String) {
        WebRenderer.log.error(message)
    }
}
