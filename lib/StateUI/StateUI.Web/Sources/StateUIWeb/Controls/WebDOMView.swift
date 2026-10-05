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

    /// Where the browser lays the view out in its layout, as last read; nil before, or where it lays it out nowhere.
    var slot: Rect?

    /// Where the view is drawn while its place travels; nil at its slot.
    var travelling: Rect?

    /// How far the view is drawn from where the browser lays it out while its place travels.
    var travelOffset: (x: Double, y: Double)?

    /// The CSS properties written over its layout's while its place travels, whose own values the cache keeps.
    var overridden: Set<String> = []

    /// The direction the view writes in, which its logical sides follow.
    private(set) var isRightToLeft = false

    /// Whether the view shows, and the opacity it stands at - what the host layer's fades read.
    private(set) var isShown = true
    private(set) var opacity = 1.0

    /// The box the view paints of its own, and whether its size is followed for a gradient in it.
    private var box = WebBox()
    private var followsSize = false

    init(tag: String) {
        node = WebRelay.create(tag)
        Self.made += 1
        serial = Self.made
        Self.liveCount += 1
    }

    /// A view of an element made already - an application's control's - which it lets go of as its own.
    init(adopting node: Int32) {
        self.node = node
        Self.made += 1
        serial = Self.made
        Self.liveCount += 1
    }

    /// A view of one of SVG's elements.
    init(vector tag: String) {
        node = WebRelay.createVector(tag)
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

    /// Sets a CSS property, or takes it away for nil; one written over while a place travels waits for it to land.
    func style(_ name: String, _ value: String?) {
        guard styles[name] != value else { return }
        styles[name] = value
        if !overridden.contains(name) { WebRelay.setStyle(node, name, value) }
    }

    /// The value of a CSS property as the view's own say keeps it.
    func styled(_ name: String) -> String? {
        styles[name]
    }

    /// Sets an attribute, or takes it away for nil.
    func attribute(_ name: String, _ value: String?) {
        WebRelay.setAttribute(node, name, value)
    }

    func setOpacity(_ opacity: Double) {
        self.opacity = opacity
        style("opacity", opacity >= 1 ? nil : WebCSS.number(max(0, opacity)))
    }

    /// Whether the view takes input; a form control greys itself.
    func setEnabled(_ enabled: Bool) {
        attribute("aria-disabled", enabled ? nil : "true")
    }

    /// Whether the view shows; a hidden one takes no room, so its layout's places are read before it goes or comes.
    func setShown(_ shown: Bool) {
        if shown != isShown { placingLayout?.placing?.beforeChange() }
        isShown = shown
        attribute("hidden", shown ? nil : "")
    }

    /// How the view is drawn over its place, its own say.
    private(set) var ownDrawing = HostDrawingTransform.identity

    /// How the layout placing the view by a run draws it, and the size the run gives it; nil while it stands in its
    /// own place.
    private(set) var placedDrawing: HostDrawingTransform?
    private(set) var placedSize: LayoutSize?

    /// Draws the view as the run placing it says, at the size the run gives it - written again whenever either
    /// changes, as the matrix turns and scales the view about a pivot of that size; nil for neither.
    /// Design: docs/design/platforms/web/layout.md#a-placing-run
    func drawInRun(_ drawing: HostDrawingTransform?, size: LayoutSize?) {
        guard drawing != placedDrawing || size != placedSize else { return }
        placedDrawing = drawing
        placedSize = size
        writeTransform()
    }

    /// How the view is drawn over its place: moved, turned, scaled about its pivot, as the host layer's matrix says -
    /// under the run that places it, where one does.
    /// Design: docs/design/platforms/web/controls.md#drawn-over-its-place
    func setTransform(_ transform: HostDrawingTransform) {
        ownDrawing = transform
        writeTransform()
    }

    /// The view's drawing: moved where its place travels, then as its transform says, for its size as drawn.
    func writeTransform(size drawn: LayoutSize? = nil) {
        let transform = ownDrawing.under(placedDrawing)
        let moved = travelOffset.map { "translate(\(WebCSS.signedPixels($0.x)), \(WebCSS.signedPixels($0.y)))" }
        guard !transform.isIdentity else {
            style("transform", moved)
            return style("transform-origin", nil)
        }
        let size = drawn ?? placedSize ?? WebRelay.size(of: node)
        let m = transform.matrix(width: size.width, height: size.height)
        let values = [m.m11, m.m12, m.m13, m.m14, m.m21, m.m22, m.m23, m.m24,
                      m.m31, m.m32, m.m33, m.m34, m.m41, m.m42, m.m43, m.m44]
        style("transform-origin", "0 0")
        let matrix = "matrix3d(" + values.map(WebCSS.number).joined(separator: ", ") + ")"
        style("transform", moved.map { $0 + " " + matrix } ?? matrix)
    }

    /// What assistive technology meets of the view: its name and what it does, its level as a heading, whether it
    /// is met at all, and the identifier a driver finds it by.
    /// Design: docs/design/platforms/web/controls.md#what-assistive-technology-meets
    func setAccessibility(_ words: AccessibilityWords) {
        attribute("data-identifier", words.identifier)
        named.attribute("aria-label", words.label?.isEmpty == false ? words.label : nil)
        named.attribute("aria-description", words.hint?.isEmpty == false ? words.hint : nil)
        let heading = words.headingLevel > 0
        attribute("role", heading ? "heading" : words.presence == .hidden ? "none" : role)
        attribute("aria-level", heading ? String(words.headingLevel) : nil)
        attribute("aria-hidden", words.presence == .hiddenWithChildren ? "true" : nil)
    }

    /// The element assistive technology names the view by: its own, or the browser's control it stands around.
    var named: WebDOMView { self }

    /// Whether the view is a control of the browser's own, which takes taps, the keyboard and a role of itself.
    var isControl: Bool { false }

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
        isRightToLeft = direction == .rightToLeft
        attribute("dir", isRightToLeft ? "rtl" : "ltr")
    }

    /// Paints the view's own box - its fill, its outline, its shape - again as its size changes where a gradient is in it.
    /// Design: docs/design/platforms/web/drawing.md#a-brush-on-a-box
    func setBox(_ box: WebBox) {
        self.box = box
        if box.followsSize, !followsSize {
            followsSize = true
            WebRelay.observeSize(node, WebRelay.listener { [weak self] in self?.writeBox() })
        }
        writeBox()
    }

    /// The view's box as it stands.
    var paintedBox: WebBox { box }

    private func writeBox() {
        let size = box.followsSize ? WebRelay.size(of: node) : LayoutSize(width: 0, height: 0)
        for (name, value) in box.styles(size: size) { style(name, value) }
    }

    /// The room kept inside the view's edge.
    func setPadding(_ padding: Insets?) {
        for (side, length) in WebCSS.sides(padding) { style("padding-\(side)", length) }
    }
}
