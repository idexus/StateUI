// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A WebView: the browser's own `<iframe>` over a box that takes no room of its own, as a web view has no size of its
/// own, showing an address, or a document written in place - of the page's own
/// site, so the page reaches into it. A document of another site the browser keeps to itself: the page knows only
/// the address it gave the frame and that it loaded, and goes back, forward or runs a script in none.
/// Design: docs/design/platforms/web/controls.md#a-web-view
@MainActor
final class WebFrameView: WebDOMView {
    var onNavigating: (WebNavigationType, String) -> Void = { _, _ in }
    var onNavigated: (WebNavigationResult, WebNavigationType, String) -> Void = { _, _, _ in }
    var onCanGoBack: (Bool) -> Void = { _ in }
    var onCanGoForward: (Bool) -> Void = { _ in }

    /// The address the page gave the frame last: a document's own `data:` address, as every host tells it.
    private var given = ""

    /// Each document written in place, by the address made for it: what the frame tells for it.
    private var written: [String: String] = [:]

    /// The address the frame told last it stands at.
    private var shown = ""
    private var history = WebHistory()
    private var cause = WebNavigationCause()
    private let frame = WebDOMView(tag: "iframe")

    init() {
        super.init(tag: "div")
        attribute("class", "stateui-frame")
        frame.attribute("referrerpolicy", "strict-origin-when-cross-origin")
        WebRelay.insert(frame.node, into: node, at: 0)
        frame.listen("load") { [weak self] in self?.loaded() }
    }

    override var named: WebDOMView { frame }

    /// Shows `source` where it changed.
    func show(_ source: WebViewSource?) {
        guard let source else { return }
        given = switch source {
        case .url(let address): address
        case .html(let document, _): WebDocument.address(of: document)
        }
        onNavigating(cause.begin(told: .newPage), given)
        if let made = WebRelay.showInFrame(frame.node, source) { written[made] = given }
    }

    /// The frame's document loaded: where it is, as far as the page can know, and its history.
    private func loaded() {
        let state = WebRelay.frameState(frame.node)
        let address = state.reachable ? WebRelay.frameAddress(frame.node) : ""
        shown = written[address] ?? (address.isEmpty ? given : address)
        onNavigated(.success, cause.current, shown)
        let changed = history.changes(back: state.back, forward: state.forward)
        if let back = changed.back { onCanGoBack(back) }
        if let forward = changed.forward { onCanGoForward(forward) }
    }

    /// Takes a step of the frame's own - back, forward, the page again - its navigation beginning for it; a document
    /// of another site takes none but the page again, which loads the address the page gave it. Whether it took one.
    func step(_ step: WebNavigationType) -> Bool {
        cause.ask(step)
        let code: Int32 = step == .back ? 0 : step == .forward ? 1 : 2
        if WebRelay.frameStep(frame.node, code) {
            onNavigating(cause.begin(told: step), shown)
            return true
        }
        guard code == 2, !given.isEmpty, !given.hasPrefix("data:") else { return false }
        frame.attribute("src", nil)
        frame.attribute("src", given)
        onNavigating(cause.begin(told: .reload), given)
        return true
    }

    /// The script's answer, from the JSON its value writes; nil where the document is of another site.
    func evaluate(_ script: String) -> (ran: Bool, answer: String?) {
        guard let json = WebRelay.evaluateInFrame(frame.node, script) else { return (false, nil) }
        return (true, ScriptAnswer.text(json: json))
    }

    override func detach() {
        frame.detach()
        super.detach()
    }
}
