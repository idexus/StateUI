// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIGTK

/// A GTK widget Swift holds, and the number its signals name it by.
/// Design: docs/design/platforms/gtk/c-api.md#a-view-and-its-number
@MainActor
class GTKView {
    /// The widget, held until this is released.
    let widget: GTKWidget

    /// The number the widget's signals hand back.
    let number: Int64

    /// The layout that places this view, which a place written between passes asks to allocate again.
    weak var placingLayout: GTKLayoutView?

    /// Where the view was last placed in its parent; nil before its first place.
    var placed: Rect?

    /// How the view's own properties move, turn and scale it.
    var transform = HostDrawingTransform.identity

    /// How a placing layout's run draws the view over its own transform, and how opaque; nil while none does.
    var placedDrawing: HostDrawingTransform?
    private(set) var placedOpacity = 1.0

    /// How opaque the view's own property draws it, and whether it shows, as the host last wrote them.
    private(set) var opacity = 1.0
    private(set) var isShown = true

    /// The controllers the view listens through, and what hears them; nil while it listens for nothing.
    private(set) var listening: GTKListening?
    private var onHeard: ((GTKHeard) -> Void)?

    /// The style sheet's class giving the view its padding.
    private var paddingClass: String?

    private static var nextNumber: Int64 = 0
    private static var live: [Int64: Weak] = [:]

    /// Takes the next number and holds the widget `make` makes, handed that number.
    init(_ make: (_ number: Int64) -> GTKWidget?) {
        Self.nextNumber += 1
        number = Self.nextNumber
        guard let widget = make(number) else { fatalError("GTK made no widget") }
        self.widget = widget
        g_object_ref_sink(widget)
        Self.live[number] = Weak(self)
    }

    /// Lets go of the widget, taking it out of a StateUI panel; any other parent - a viewport, a window - is the
    /// owner of its child, and takes it out itself.
    isolated deinit {
        Self.live[number] = nil
        if let parent = gtk_widget_get_parent(widget), GTKPanel.holds(parent) { gtk_widget_unparent(widget) }
        g_object_unref(widget)
    }

    /// The live view a signal names; nil once it has left.
    static func find(_ number: Int64) -> GTKView? {
        live[number]?.view
    }

    /// How many views Swift holds - what a test counts to see every one let go.
    static var liveCount: Int { live.count }

    /// Connects `handler` to the widget's `signal`, handing it this view's number.
    func connect(_ signal: String, _ handler: GTKSignalHandler) {
        connectSignal(UnsafeMutableRawPointer(widget), signal, number: number, handler)
    }

    /// Connects `handler` to the widget's `notify::<property>`, handing it this view's number.
    func notify(_ property: String, _ handler: GTKArgumentHandler) {
        connectNotify(UnsafeMutableRawPointer(widget), property, number: number, handler)
    }

    // MARK: - What every view takes

    func setShown(_ shown: Bool) {
        isShown = shown
        gtk_widget_set_visible(widget, shown ? 1 : 0)
    }

    /// How opaque the view's own property draws it, under a placing run's opacity; written only where it differs.
    func setOpacity(_ opacity: Double) {
        guard opacity != self.opacity else { return }
        self.opacity = opacity
        gtk_widget_set_opacity(widget, opacity * placedOpacity)
    }

    /// How a placing layout's run draws the view, and how opaque, over its own; nil draws it as its own say.
    func setPlacedDrawing(_ drawing: HostDrawingTransform?, opacity: Double) {
        guard drawing != placedDrawing || opacity != placedOpacity else { return }
        placedDrawing = drawing
        placedOpacity = opacity
        gtk_widget_set_opacity(widget, self.opacity * opacity)
        if let placingLayout { gtk_widget_queue_allocate(placingLayout.widget) }
    }

    /// Whether clicks and touches go through the view to what is behind it.
    func setIgnoresInput(_ ignores: Bool) {
        gtk_widget_set_can_target(widget, ignores ? 0 : 1)
    }

    /// The room between the view's edge and its content, as a class of the host's style sheet; nil for none.
    func setPadding(_ insets: Insets?) {
        let wanted = insets.flatMap { $0 == Insets(0) ? nil : GTKStyleSheet.padding($0) }
        guard wanted != paddingClass else { return }
        if let paddingClass { gtk_widget_remove_css_class(widget, paddingClass) }
        if let wanted { gtk_widget_add_css_class(widget, wanted) }
        paddingClass = wanted
    }

    func setEnabled(_ enabled: Bool) {
        gtk_widget_set_sensitive(widget, enabled ? 1 : 0)
    }

    /// Asks GTK to measure this widget again, and every widget above it.
    func invalidateMeasure() {
        gtk_widget_queue_resize(widget)
    }

    /// The widget's size for the room offered, in logical pixels; nil offers any. Its natural width, no wider
    /// than offered nor narrower than its least, and its natural height for that width.
    /// Design: docs/design/platforms/gtk/layout.md#measuring-a-widget
    func measure(width: Double?, height: Double?) -> LayoutSize {
        var least: Int32 = 0
        var natural: Int32 = 0
        gtk_widget_measure(widget, GTK_ORIENTATION_HORIZONTAL, -1, &least, &natural, nil, nil)
        var measuredWidth = Double(natural)
        if let width { measuredWidth = max(Double(least), min(measuredWidth, width.rounded(.down))) }

        gtk_widget_measure(widget, GTK_ORIENTATION_VERTICAL, Int32(measuredWidth), &least, &natural, nil, nil)
        return LayoutSize(width: measuredWidth, height: Double(natural))
    }

    /// Where the view stands, in logical pixels: its frame in its parent, its place in the window, and that place
    /// from the top left of its page's content, beneath the page's header bar.
    /// Design: docs/design/platforms/gtk/layout.md#where-a-view-stands
    func frameReport() -> [Double] {
        let place = placed ?? laidOutFrame
        guard let root = gtk_widget_get_root(widget).map(GTKWidget.init) else {
            return [place.x, place.y, place.width, place.height, place.x, place.y, place.x, place.y]
        }
        let corner = Self.origin(of: widget, in: root)
        var page = (x: 0.0, y: 0.0)
        var ancestor = gtk_widget_get_parent(widget)
        while let each = ancestor {
            if g_type_check_instance_is_a(each.of(GTypeInstance.self), adw_toolbar_view_get_type()) != 0,
               let content = adw_toolbar_view_get_content(each.opaque) {
                page = Self.origin(of: content, in: root)
                break
            }
            ancestor = gtk_widget_get_parent(each)
        }
        return [place.x, place.y, place.width, place.height, corner.x, corner.y, corner.x - page.x, corner.y - page.y]
    }

    private static func origin(of widget: GTKWidget, in root: GTKWidget) -> (x: Double, y: Double) {
        var from = graphene_point_t(x: 0, y: 0)
        var to = graphene_point_t()
        guard gtk_widget_compute_point(widget, root, &from, &to) != 0 else { return (0, 0) }
        return (Double(to.x), Double(to.y))
    }

    /// Where GTK laid the widget out in its parent, in logical pixels, its CSS box and transform included.
    var laidOutFrame: Rect {
        var bounds = graphene_rect_t()
        guard let parent = gtk_widget_get_parent(widget), gtk_widget_compute_bounds(widget, parent, &bounds) != 0
        else { return Rect(x: 0, y: 0, width: 0, height: 0) }
        return Rect(
            x: Double(bounds.origin.x), y: Double(bounds.origin.y),
            width: Double(bounds.size.width), height: Double(bounds.size.height))
    }

    /// What the view listens for of the user's input.
    var hearing: GTKHearing { listening?.hearing ?? [] }

    /// Listens for what `hearing` names, `heard` hearing it; a panel listening for taps is pressable by
    /// assistive technology.
    /// Design: docs/design/platforms/gtk/input.md#listening
    func hear(_ hearing: GTKHearing, _ heard: @escaping (GTKHeard) -> Void) {
        onHeard = hearing.isEmpty ? nil : heard
        guard hearing != self.hearing else { return }

        if GTKPanel.holds(widget) { GTKPanel.setPressable(widget, hearing.contains(.taps)) }
        let listening = listening ?? GTKListening(widget: widget, number: number)
        listening.listen(for: hearing)
        self.listening = hearing.isEmpty ? nil : listening
    }

    /// What the view heard, handed to what hears it.
    func heard(_ heard: GTKHeard) {
        onHeard?(heard)
    }

    /// The user clicked the view.
    func clicked() {}

    /// The element left the tree: the view lets go of everything that would call back into it. An override
    /// calls this first.
    func detach() {
        hear([]) { _ in }
    }

    private struct Weak {
        weak var view: GTKView?

        init(_ view: GTKView) { self.view = view }
    }
}
