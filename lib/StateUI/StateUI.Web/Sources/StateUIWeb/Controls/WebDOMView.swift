// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A view of the Web host: one DOM element the relay keeps, made with the view and let go of when its element
/// leaves the tree, with every listener hung on it.
/// Design: docs/design/platforms/web/controls.md#a-view
@MainActor
class WebDOMView {
    /// The relay's number for the DOM element.
    let node: Int32

    /// How many views are alive, for the tally.
    private(set) static var liveCount = 0

    /// The listeners hung on the element, let go of with it.
    private var listeners: [Int32] = []

    /// The CSS properties this view's element holds, by name, so a value is sent only when it changes.
    private var styles: [String: String] = [:]

    /// The layout this view stands in, which writes its place.
    weak var placingLayout: WebLayoutView?

    init(tag: String) {
        node = WebRelay.create(tag)
        Self.liveCount += 1
    }

    /// Takes the element off the page and lets go of it and of everything hung on it.
    func detach() {
        for listener in listeners { WebRelay.forget(listener) }
        listeners = []
        WebRelay.release(node)
        Self.liveCount -= 1
    }

    /// Runs `action` whenever the element hears `event`.
    func listen(_ event: String, _ action: @escaping @MainActor () -> Void) {
        let listener = WebRelay.listener(action)
        listeners.append(listener)
        WebRelay.listen(node, event, listener)
    }

    /// Sets a CSS property, or takes it away for nil.
    func style(_ name: String, _ value: String?) {
        guard styles[name] != value else { return }
        styles[name] = value
        WebRelay.setStyle(node, name, value)
    }

    /// Sets an attribute, or takes it away for nil.
    func attribute(_ name: String, _ value: String?) {
        WebRelay.setAttribute(node, name, value)
    }

    func setOpacity(_ opacity: Double) {
        style("opacity", opacity >= 1 ? nil : WebCSS.number(max(0, opacity)))
    }

    /// Whether the view takes input; a form control greys itself.
    func setEnabled(_ enabled: Bool) {
        attribute("aria-disabled", enabled ? nil : "true")
    }

    /// Whether the view shows; a hidden one takes no room.
    func setShown(_ shown: Bool) {
        attribute("hidden", shown ? nil : "")
    }

    /// The direction the view lays out and writes in.
    func setDirection(_ direction: LayoutDirection) {
        attribute("dir", direction == .rightToLeft ? "rtl" : "ltr")
    }

    /// The room kept inside the view's edge.
    func setPadding(_ padding: Insets?) {
        for (side, length) in WebCSS.sides(padding) { style("padding-\(side)", length) }
    }
}
