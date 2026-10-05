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

    /// When the view was made among every view of the page - the order the display's frames serve them in; the
    /// relay makes a number let go of again, so its number is no order.
    let serial: Int64
    private static var made: Int64 = 0

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
        Self.made += 1
        serial = Self.made
        Self.liveCount += 1
    }

    /// Whether the element has been let go of: its number may be another element's by now.
    private(set) var isReleased = false

    /// Takes the element off the page and lets go of it and of everything hung on it, once.
    func detach() {
        guard !isReleased else { return }
        isReleased = true
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

    /// How the view is drawn over its place, its own say.
    private var ownDrawing = HostDrawingTransform.identity

    /// How the layout placing the view by a run draws it; nil while it stands in its own place.
    var placedDrawing: HostDrawingTransform? {
        didSet { if placedDrawing != oldValue { writeTransform() } }
    }

    /// How the view is drawn over its place: moved, turned, scaled about its pivot, as the host layer's matrix says -
    /// under the run that places it, where one does.
    /// Design: docs/design/platforms/web/controls.md#drawn-over-its-place
    func setTransform(_ transform: HostDrawingTransform) {
        ownDrawing = transform
        writeTransform()
    }

    private func writeTransform() {
        let transform = ownDrawing.under(placedDrawing)
        guard !transform.isIdentity else {
            style("transform", nil)
            return style("transform-origin", nil)
        }
        let size = WebRelay.size(of: node)
        let m = transform.matrix(width: size.width, height: size.height)
        let values = [m.m11, m.m12, m.m13, m.m14, m.m21, m.m22, m.m23, m.m24,
                      m.m31, m.m32, m.m33, m.m34, m.m41, m.m42, m.m43, m.m44]
        style("transform-origin", "0 0")
        style("transform", "matrix3d(" + values.map(WebCSS.number).joined(separator: ", ") + ")")
    }

    /// What assistive technology meets of the view: its name and what it does, its level as a heading, whether it
    /// is met at all, and the identifier a driver finds it by.
    /// Design: docs/design/platforms/web/controls.md#what-assistive-technology-meets
    func setAccessibility(_ words: AccessibilityWords) {
        attribute("data-identifier", words.identifier)
        attribute("aria-label", words.label?.isEmpty == false ? words.label : nil)
        attribute("aria-description", words.hint?.isEmpty == false ? words.hint : nil)
        let heading = words.headingLevel > 0
        attribute("role", heading ? "heading" : words.presence == .hidden ? "none" : role)
        attribute("aria-level", heading ? String(words.headingLevel) : nil)
        attribute("aria-hidden", words.presence == .hiddenWithChildren ? "true" : nil)
    }

    /// The role the view plays where nothing says otherwise: a container the user taps is a button.
    var role: String? {
        isTapped ? "button" : nil
    }

    /// Whether the user taps the view though it is no control of the browser's own.
    var isTapped = false {
        didSet {
            guard isTapped != oldValue else { return }
            attribute("data-taps", isTapped ? "" : nil)
            attribute("tabindex", isTapped ? "0" : nil)
            attribute("role", role)
        }
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
