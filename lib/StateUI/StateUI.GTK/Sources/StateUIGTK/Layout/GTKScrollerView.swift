// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// GTK's `GtkScrolledWindow`, which a ScrollView stands over its whole room around the document it moves, the
/// document in a viewport that gives it its natural size the ways it scrolls.
/// Design: docs/design/platforms/gtk/layout.md#scrolling
@MainActor
final class GTKScrollerView: GTKView {
    /// Says where the view stands after it changed.
    var onScrolled: ((Point) -> Void)?

    /// Says the user took hold of the scroller - a touchpad's fingers down - or let go of it.
    var onHeld: ((Bool) -> Void)?

    private var content: GTKView?

    init() {
        super.init { _ in gtk_scrolled_window_new() }
        for adjustment in [horizontal, vertical] {
            connectSignal(UnsafeMutableRawPointer(adjustment), "value-changed", number: number) { _, data in
                MainActor.assumeIsolated {
                    guard let view = GTKView.find(viewNumber(data)) as? GTKScrollerView else { return }
                    view.onScrolled?(view.standing.offset)
                    GTKRenderer.shared?.runtime.frames.laidOut()
                }
            }
        }

        let fingers = gtk_event_controller_scroll_new(GTK_EVENT_CONTROLLER_SCROLL_BOTH_AXES)!
        gtk_event_controller_set_propagation_phase(fingers, GTK_PHASE_CAPTURE)
        connectSignal(UnsafeMutableRawPointer(fingers), "scroll-begin", number: number) { _, data in
            MainActor.assumeIsolated { (GTKView.find(viewNumber(data)) as? GTKScrollerView)?.onHeld?(true) }
        }
        connectSignal(UnsafeMutableRawPointer(fingers), "scroll-end", number: number) { _, data in
            MainActor.assumeIsolated { (GTKView.find(viewNumber(data)) as? GTKScrollerView)?.onHeld?(false) }
        }
        gtk_widget_add_controller(widget, fingers)
    }

    /// The scrolled window takes its document out of its viewport before it goes.
    isolated deinit {
        gtk_scrolled_window_set_child(scrolled, nil)
    }

    private var scrolled: OpaquePointer { widget.opaque }
    private var horizontal: UnsafeMutablePointer<GtkAdjustment> { gtk_scrolled_window_get_hadjustment(scrolled) }
    private var vertical: UnsafeMutablePointer<GtkAdjustment> { gtk_scrolled_window_get_vadjustment(scrolled) }

    /// The document it moves, the ways it scrolls, and its bars: the viewport gives the document its natural size
    /// along the ways it scrolls and the viewport's size across.
    func set(
        content: GTKView, orientation: ScrollOrientation, verticalBar: ScrollBarVisibility,
        horizontalBar: ScrollBarVisibility
    ) {
        if content !== self.content {
            self.content = content
            gtk_scrolled_window_set_child(scrolled, content.widget)
        }
        let across = orientation == .horizontal || orientation == .both
        let down = orientation == .vertical || orientation == .both
        gtk_scrolled_window_set_policy(
            scrolled, Self.policy(scrolls: across, horizontalBar), Self.policy(scrolls: down, verticalBar))
        if let viewport = gtk_scrolled_window_get_child(scrolled), viewport != content.widget {
            gtk_scrollable_set_hscroll_policy(viewport.opaque, across ? GTK_SCROLL_NATURAL : GTK_SCROLL_MINIMUM)
            gtk_scrollable_set_vscroll_policy(viewport.opaque, down ? GTK_SCROLL_NATURAL : GTK_SCROLL_MINIMUM)
        }
    }

    /// A way the view scrolls, with its bar as asked; a way it does not scroll holds the document to the viewport.
    private static func policy(scrolls: Bool, _ bar: ScrollBarVisibility) -> GtkPolicyType {
        guard scrolls else { return GTK_POLICY_NEVER }
        return switch bar {
        case .always: GTK_POLICY_ALWAYS
        case .never: GTK_POLICY_EXTERNAL
        default: GTK_POLICY_AUTOMATIC
        }
    }

    /// Moves the view to `target` at once.
    func move(to target: Point) {
        gtk_adjustment_set_value(horizontal, target.x)
        gtk_adjustment_set_value(vertical, target.y)
    }

    /// Where the view stands, and the farthest it reaches.
    var standing: (offset: Point, reach: Point) {
        func reach(_ adjustment: UnsafeMutablePointer<GtkAdjustment>) -> Double {
            max(0, gtk_adjustment_get_upper(adjustment) - gtk_adjustment_get_page_size(adjustment))
        }
        return (
            Point(x: gtk_adjustment_get_value(horizontal), y: gtk_adjustment_get_value(vertical)),
            Point(x: reach(horizontal), y: reach(vertical)))
    }

    override func detach() {
        super.detach()
        onScrolled = nil
        onHeld = nil
    }
}
