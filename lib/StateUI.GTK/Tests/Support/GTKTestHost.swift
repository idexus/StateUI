// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@testable import StateUIGTK
import XCTest

/// The smallest complete application around one page: one scene, one window.
struct OneWindowApplication: Application {
    let page: @Sendable () -> any Page

    var scene: any Scene { OneWindow(content: page) }
}

/// The window of a `OneWindowApplication`, its page built again each time the window is.
struct OneWindow: Window {
    let content: @Sendable () -> any Page

    var page: any Page { content() }
}

/// What a handler heard, in order.
final class Received<Value>: Sendable {
    private let received = State(wrappedValue: [Value]())

    var values: [Value] {
        get { received.wrappedValue }
        set { received.wrappedValue = newValue }
    }
}

/// A clock a test winds by hand, in milliseconds.
@MainActor
final class TestClock {
    var now = 0.0
}

/// The test thread as GTK's: libadwaita started once, and an application registered for the windows, with no
/// loop of GLib's running a test.
@MainActor
enum GTKTestHost {
    /// The application every test's windows belong to.
    static let application: UnsafeMutablePointer<GtkApplication> = {
        adw_init()
        let application = adw_application_new("com.stateui.GTKTests", G_APPLICATION_NON_UNIQUE)!
        precondition(
            g_application_register(application.of(GApplication.self), nil, nil) != 0,
            "the test application could not register")
        return application.of(GtkApplication.self)
    }()

    /// Tests/Resources/Images, beside this file's folder.
    static let pictures: String = {
        var path = #filePath
        for _ in 0..<2 { path = String(path[..<(path.lastIndex(of: "/") ?? path.endIndex)]) }
        return path + "/Resources/Images"
    }()

    /// The window a bare host's root stands in, made once.
    static let window = GTKWindow(application: application)

    /// Lays `window` out now, at its surface's size: the surface's `layout` signal, which the frame clock raises
    /// in a frame's layout. A window a test opens may stand behind another, where the desktop draws it no frames,
    /// so a test lays out without waiting for one.
    static func layOut(_ window: GTKWidget) {
        guard let surface = gtk_native_get_surface(window.opaque) else { return pump(0.05) }
        let width = gdk_surface_get_width(surface)
        let height = gdk_surface_get_height(surface)
        guard width > 0, height > 0 else { return pump(0.05) }

        var values = [GValue](repeating: GValue(), count: 3)
        g_value_init(&values[0], gdk_surface_get_type())
        g_value_set_object(&values[0], UnsafeMutableRawPointer(surface))
        g_value_init(&values[1], g_type_from_name("gint"))
        g_value_set_int(&values[1], width)
        g_value_init(&values[2], g_type_from_name("gint"))
        g_value_set_int(&values[2], height)
        values.withUnsafeMutableBufferPointer { values in
            g_signal_emitv(values.baseAddress, g_signal_lookup("layout", gdk_surface_get_type()), 0, nil)
            for index in values.indices { g_value_unset(&values[index]) }
        }
    }

    /// Emits `signal` of `instance` as GTK does, handing it `numbers` in order - each parameter an integer or a
    /// double, and nothing for a parameter GTK hands by address.
    static func emit(_ instance: OpaquePointer, _ signal: String, _ numbers: [Double] = []) {
        let type = UnsafeMutablePointer<GTypeInstance>(instance).pointee.g_class.pointee.g_type
        let id = g_signal_lookup(signal, type)
        precondition(id != 0, "no signal \(signal)")
        var query = GSignalQuery()
        g_signal_query(id, &query)

        var values = [GValue](repeating: GValue(), count: Int(query.n_params) + 1)
        g_value_init(&values[0], type)
        g_value_set_object(&values[0], UnsafeMutableRawPointer(instance))
        for index in 0..<Int(query.n_params) {
            let parameter = query.param_types[index] & ~GType(1)
            g_value_init(&values[index + 1], parameter)
            let number = index < numbers.count ? numbers[index] : 0
            switch g_type_fundamental(parameter) {
            case g_type_from_name("gint"): g_value_set_int(&values[index + 1], Int32(number))
            case g_type_from_name("guint"): g_value_set_uint(&values[index + 1], UInt32(number))
            case g_type_from_name("gdouble"): g_value_set_double(&values[index + 1], number)
            default: break
            }
        }
        values.withUnsafeMutableBufferPointer { values in
            g_signal_emitv(values.baseAddress, id, 0, nil)
            for index in values.indices { g_value_unset(&values[index]) }
        }
    }

    /// Turns GLib's loop for `seconds`: a window's first frame, and the layout GTK does on it.
    static func pump(_ seconds: Double = 0.2) {
        let end = g_get_monotonic_time() + gint64(seconds * 1_000_000)
        repeat {
            while g_main_context_iteration(nil, 0) != 0 {}
            g_usleep(2_000)
        } while g_get_monotonic_time() < end
    }
}

extension XCTestCase {
    /// Runs `body` as the main actor's on the test thread, which holds GTK: a drain makes it MainActor's first.
    func onUIThread(_ body: @MainActor () throws -> Void) rethrows {
        _ = CoreLink().runJobs()
        try MainActor.assumeIsolated(body)
    }
}

extension GTKRenderer {
    /// A host showing `page` in a window of its own, laid out, on `clock` where one is given.
    static func running(
        clock: TestClock? = nil, reducesMotion: Bool = false, _ page: @escaping @Sendable () -> any Page
    ) -> GTKRenderer {
        stateUIUseApp(OneWindowApplication(page: page))
        let renderer = replacing(clock: clock, reducesMotion: reducesMotion)
        renderer.show()
        GTKTestHost.pump()
        renderer.layOut()
        return renderer
    }

    /// A host whose tree takes only what a test applies; its root stands in the test's window. The core's own
    /// render is taken and set aside, so no frame renders the core's tree over the test's.
    static func bare(clock: TestClock? = nil, reducesMotion: Bool = false) -> GTKRenderer {
        let renderer = replacing(clock: clock, reducesMotion: reducesMotion)
        _ = renderer.core.render(baseline: 0)
        return renderer
    }

    /// A host in place of the one before it, which leaves; its window closes.
    private static func replacing(clock: TestClock?, reducesMotion: Bool) -> GTKRenderer {
        shared?.tree.root?.leave()
        shared?.window?.close()
        GTKTestHost.window.show(nil)

        let renderer = GTKRenderer(
            application: GTKTestHost.application, clock: clock.map { clock in { clock.now } },
            reducesMotion: { reducesMotion })
        shared = renderer
        return renderer
    }

    /// Applies `patch` as one whole message, as a render does, and stands the root in the test's window.
    func apply(_ patch: HostPatch) {
        intake.take(patch, generation: intake.baseline &+ 1) { tree.apply($0, complete: true) }
        let root = (tree.root?.native as? GTKElement)?.view
        guard GTKTestHost.window.content !== root else { return }
        GTKTestHost.window.show(root)
        GTKTestHost.pump()
        layOut()
    }

    /// The view of the element keyed `id`.
    func view(id: ElementId) -> GTKView? {
        (tree.root?.first(id: id)?.native as? GTKElement)?.view
    }

    /// One display frame at the clock's time, then the layout GTK runs in it.
    func frame() {
        displayCycle.frame(now: frameClock.now())
        layOut()
    }

    /// Runs GTK's layout of the shown window now.
    func layOut() {
        GTKTestHost.layOut((window ?? GTKTestHost.window).widget)
    }

    /// Turns until `done` holds: a handler resumed on the pool comes back to the UI thread's queue, and a display
    /// frame runs while something asks for one - a window behind another gets none from the desktop.
    func settle(until done: () -> Bool) {
        for _ in 0..<150 where !done() {
            GTKTestHost.pump(0.01)
            _ = core.runJobs()
            pump.turn()
            if frameClock.held { frame() }
        }
    }

    /// The window's name, as GTK holds it.
    var windowTitle: String? {
        guard let window, let title = gtk_window_get_title(window.widget.of(GtkWindow.self)) else { return nil }
        return String(cString: title)
    }

    /// Every view of `type` in the tree, in order.
    func views<Native: GTKView>(_ type: Native.Type) -> [Native] {
        guard let root = tree.root else { return [] }
        return Self.views(type, in: root)
    }

    private static func views<Native: GTKView>(_ type: Native.Type, in element: MountedElement) -> [Native] {
        let own = ((element.native as? GTKElement)?.view as? Native).map { [$0] } ?? []
        return own + element.children.flatMap { views(type, in: $0) }
    }
}

extension GTKView {
    /// Where GTK laid the widget out, rounded to whole pixels.
    var frame: (x: Double, y: Double, width: Double, height: Double) {
        let frame = laidOutFrame
        return (frame.x.rounded(), frame.y.rounded(), frame.width.rounded(), frame.height.rounded())
    }

    /// One step of the opacity GTK keeps, in 256 steps.
    static let opacityStep = 1.0 / 255

    /// The opacity GTK draws the widget at.
    var drawnOpacity: Double {
        gtk_widget_get_opacity(widget)
    }

    /// Where GTK draws the widget's own point `point`, in its parent's coordinates.
    func drawn(_ point: (x: Double, y: Double)) -> (x: Double, y: Double) {
        var from = graphene_point_t(x: Float(point.x), y: Float(point.y))
        var to = graphene_point_t()
        _ = gtk_widget_compute_point(widget, gtk_widget_get_parent(widget), &from, &to)
        return (Double(to.x), Double(to.y))
    }
}

extension GTKView {
    /// The colours GTK draws the widget in at `points`, in its own coordinates, as premultiplied ARGB: the widget
    /// drawn afresh from its parent, as a frame's paint draws it, and rendered by its window's renderer.
    func pixels(at points: [(Double, Double)]) -> [UInt32] {
        let width = Int(gtk_widget_get_width(widget))
        let height = Int(gtk_widget_get_height(widget))
        var bounds = graphene_rect_t()
        guard width > 0, height > 0, let parent = gtk_widget_get_parent(widget),
              gtk_widget_compute_bounds(widget, parent, &bounds) != 0,
              let native = gtk_widget_get_native(widget), let renderer = gtk_native_get_renderer(native)
        else { return points.map { _ in 0 } }

        let snapshot = gtk_snapshot_new()
        gtk_widget_snapshot_child(parent, widget, snapshot)
        guard let node = gtk_snapshot_free_to_node(snapshot) else { return points.map { _ in 0 } }
        defer { gsk_render_node_unref(node) }
        var viewport = graphene_rect_t(
            origin: bounds.origin, size: graphene_size_t(width: Float(width), height: Float(height)))
        guard let texture = gsk_renderer_render_texture(renderer, node, &viewport) else { return points.map { _ in 0 } }
        defer { g_object_unref(UnsafeMutableRawPointer(texture)) }

        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        gdk_texture_download(texture, &bytes, gsize(width * 4))
        return points.map { point in
            let (x, y) = (Int(point.0), Int(point.1))
            guard x >= 0, y >= 0, x < width, y < height else { return 0 }
            let at = (y * width + x) * 4
            return UInt32(bytes[at + 3]) << 24 | UInt32(bytes[at + 2]) << 16 | UInt32(bytes[at + 1]) << 8
                | UInt32(bytes[at])
        }
    }
}

/// Whether two ARGB colours differ by at most `tolerance` in each channel - GTK rounds an opacity to 256 steps.
func near(_ a: UInt32, _ b: UInt32, within tolerance: Int = 2) -> Bool {
    (0..<4).allSatisfy { shift in
        abs(Int((a >> (shift * 8)) & 0xFF) - Int((b >> (shift * 8)) & 0xFF)) <= tolerance
    }
}

extension GTKNavigationView {
    /// The title of the page GTK shows.
    var visiblePageTitle: String? {
        guard let navigation = gtk_widget_get_first_child(widget),
              let page = adw_navigation_view_get_visible_page(navigation.opaque),
              let title = adw_navigation_page_get_title(page)
        else { return nil }
        return String(cString: title)
    }
}

extension GTKSwitchView {
    /// Turns the switch as the user's click does.
    func toggle() {
        gtk_switch_set_active(widget.opaque, isOn ? 0 : 1)
    }
}

extension GTKSliderView {
    /// Moves the thumb to `value` as the user's drag does.
    func move(to value: Double) {
        gtk_range_set_value(widget.of(GtkRange.self), value)
    }
}

extension GTKTextFieldView {
    /// Changes the field's words as the user's typing does: written outside a program's write.
    func type(_ text: String) {
        gtk_editable_set_text(widget.opaque, text)
    }
}

extension GTKButtonView {
    /// Clicks the button as the pointer's release does - its `clicked` signal - then lets GTK lay out what that
    /// changed.
    func click() {
        var instance = GValue()
        g_value_init(&instance, gtk_button_get_type())
        g_value_set_object(&instance, UnsafeMutableRawPointer(widget))
        g_signal_emitv(&instance, g_signal_lookup("clicked", gtk_button_get_type()), 0, nil)
        g_value_unset(&instance)
        GTKTestHost.pump(0.05)
    }
}
