// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
import GalleryUI
import StateUIGTK

/// Three lamps in a housing, one lit at a time - a `GtkDrawingArea` that knows nothing of StateUI.
///
/// `register()`, at the end of this file, adds it for `TrafficLightContract`, and that registration is the whole
/// bridge. The Swift half is Sources/Samples/Interop/TrafficLight.swift.
@MainActor
final class TrafficLightWidget: GTKControl {
    let widget: UnsafeMutablePointer<GtkWidget>

    /// A lamp was tapped; the argument is its index, top to bottom. The control does not switch itself: it reports,
    /// and whoever owns the state decides.
    var onLampTapped: ((Int) -> Void)?

    /// Which lamp is lit.
    var signal = TrafficSignal.stop {
        didSet { if signal != oldValue { gtk_widget_queue_draw(widget) } }
    }

    private static let lampColors: [(red: Double, green: Double, blue: Double)] = [
        (0.898, 0.282, 0.302), (0.961, 0.710, 0.275), (0.275, 0.706, 0.373),
    ]
    private static let lampSide = 44.0
    private static let spacing = 10.0
    private static let padding = 12.0

    private let click: OpaquePointer

    /// The housing and its three lamps, drawn by cairo, and one click gesture read by where it lands.
    init() {
        widget = gtk_drawing_area_new()
        g_object_ref_sink(widget)
        click = gtk_gesture_click_new()
        let area = UnsafeMutablePointer<GtkDrawingArea>(OpaquePointer(widget))
        gtk_drawing_area_set_content_width(area, Int32(Self.padding * 2 + Self.lampSide))
        gtk_drawing_area_set_content_height(area, Int32(Self.padding * 2 + Self.lampSide * 3 + Self.spacing * 2))

        // A C callback carries no context: the control rides along as its data, and lives as long as the widget.
        let me = Unmanaged.passUnretained(self).toOpaque()
        gtk_drawing_area_set_draw_func(area, { _, cairo, width, height, data in
            nonisolated(unsafe) let cairo = cairo
            MainActor.assumeIsolated {
                Unmanaged<TrafficLightWidget>.fromOpaque(data!).takeUnretainedValue()
                    .draw(cairo, width: Double(width), height: Double(height))
            }
        }, me, nil)

        let released: @convention(c) (OpaquePointer?, Int32, Double, Double, gpointer?) -> Void = { _, _, x, y, data in
            MainActor.assumeIsolated {
                Unmanaged<TrafficLightWidget>.fromOpaque(data!).takeUnretainedValue().clicked(x: x, y: y)
            }
        }
        g_signal_connect_data(
            UnsafeMutableRawPointer(click), "released", unsafeBitCast(released, to: GCallback.self), me, nil,
            GConnectFlags(0))
        gtk_widget_add_controller(widget, click)
    }

    isolated deinit {
        gtk_drawing_area_set_draw_func(UnsafeMutablePointer<GtkDrawingArea>(OpaquePointer(widget)), nil, nil, nil)
        gtk_widget_remove_controller(widget, click)
        g_object_unref(widget)
    }

    /// Where lamp `index` stands in a widget `width` wide.
    private func lampCentre(_ index: Int, width: Double) -> (x: Double, y: Double) {
        (width / 2, Self.padding + Self.lampSide / 2 + Double(index) * (Self.lampSide + Self.spacing))
    }

    /// The housing, the lit lamp at full colour and the others dimmed to embers.
    private func draw(_ cairo: OpaquePointer?, width: Double, height: Double) {
        let radius = 18.0
        cairo_new_sub_path(cairo)
        cairo_arc(cairo, width - radius, radius, radius, -Double.pi / 2, 0)
        cairo_arc(cairo, width - radius, height - radius, radius, 0, Double.pi / 2)
        cairo_arc(cairo, radius, height - radius, radius, Double.pi / 2, Double.pi)
        cairo_arc(cairo, radius, radius, radius, Double.pi, Double.pi * 3 / 2)
        cairo_close_path(cairo)
        cairo_set_source_rgb(cairo, 0.102, 0.090, 0.145)
        cairo_fill(cairo)

        for (index, color) in Self.lampColors.enumerated() {
            let centre = lampCentre(index, width: width)
            cairo_arc(cairo, centre.x, centre.y, Self.lampSide / 2, 0, Double.pi * 2)
            cairo_set_source_rgba(cairo, color.red, color.green, color.blue, Int32(index) == signal.rawValue ? 1 : 0.18)
            cairo_fill(cairo)
        }
    }

    /// Which lamp the click landed on, reported - the state decides what is lit next.
    private func clicked(x: Double, y: Double) {
        let width = Double(gtk_widget_get_width(widget))
        for index in Self.lampColors.indices {
            let centre = lampCentre(index, width: width)
            if abs(x - centre.x) <= Self.lampSide / 2, abs(y - centre.y) <= Self.lampSide / 2 {
                onLampTapped?(index)
                return
            }
        }
    }
}

// MARK: - Registration

extension TrafficLightWidget {
    /// Adds the light for `TrafficLightContract`: `create` makes the control once per element and wires the tap it
    /// reports, and `property` puts the described signal on it. Said once, before the application runs.
    @MainActor
    static func register() {
        StateUIControls.add(TrafficLightContract.self, create: { reports -> TrafficLightWidget in
            let light = TrafficLightWidget()
            light.onLampTapped = { index in reports.raise(TrafficLightContract.lampTapped, index) }
            return light
        }) { light in
            light.property(TrafficLightContract.signal) { control, signal in
                control.signal = signal ?? .stop
            }
            light.raises(TrafficLightContract.lampTapped)
        }
    }
}
