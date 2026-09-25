// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
import GalleryUI
import StateUIGTK

/// Five stars in a row, as many lit as the rating - a `GtkBox` of labels that knows nothing of StateUI.
///
/// The Swift half is Sources/Samples/Interop/RatingBar.swift; the act aimed at a bar, `flash`, is registered at the
/// end of this file beside the control it flashes.
@MainActor
final class RatingBarWidget: GTKControl {
    let widget: UnsafeMutablePointer<GtkWidget>

    /// The user chose a rating, 1 through 5.
    var onRatingChanged: ((Double) -> Void)?

    /// How many stars are lit.
    var rating = 0.0 {
        didSet { if rating != oldValue { repaint() } }
    }

    private var stars: [UnsafeMutablePointer<GtkWidget>] = []
    private let click: OpaquePointer
    private var flashing: UnsafeMutablePointer<AdwAnimation>?

    /// Five labels in a box, and ONE click gesture on the row, the star read from the click's position.
    init() {
        widget = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6)
        g_object_ref_sink(widget)
        for _ in 0..<5 {
            let star = gtk_label_new("★")!
            gtk_box_append(UnsafeMutablePointer<GtkBox>(OpaquePointer(widget)), star)
            stars.append(star)
        }

        click = gtk_gesture_click_new()
        let released: @convention(c) (OpaquePointer?, Int32, Double, Double, gpointer?) -> Void = { _, _, x, _, data in
            MainActor.assumeIsolated {
                Unmanaged<RatingBarWidget>.fromOpaque(data!).takeUnretainedValue().clicked(x: x)
            }
        }
        g_signal_connect_data(
            UnsafeMutableRawPointer(click), "released", unsafeBitCast(released, to: GCallback.self),
            Unmanaged.passUnretained(self).toOpaque(), nil, GConnectFlags(0))
        gtk_widget_add_controller(widget, click)
        repaint()
    }

    isolated deinit {
        gtk_widget_remove_controller(widget, click)
        if let flashing { g_object_unref(UnsafeMutableRawPointer(flashing)) }
        g_object_unref(widget)
    }

    /// Dims the bar and brings it back: libadwaita's own animation of its opacity, there and back once.
    func flash() {
        if let flashing { g_object_unref(UnsafeMutableRawPointer(flashing)) }
        let target = adw_property_animation_target_new(UnsafeMutablePointer<GObject>(OpaquePointer(widget)), "opacity")
        let animation = adw_timed_animation_new(widget, 1, 0.25, 120, target)!
        let timed = OpaquePointer(animation)
        adw_timed_animation_set_alternate(timed, 1)
        adw_timed_animation_set_repeat_count(timed, 2)
        adw_animation_play(animation)
        flashing = animation
    }

    /// The star the click landed on, as the user's rating.
    private func clicked(x: Double) {
        let width = Double(gtk_widget_get_width(widget))
        guard width > 0 else { return }
        let chosen = Double(min(max(Int(x / (width / 5)), 0), 4) + 1)
        rating = chosen
        onRatingChanged?(chosen)
    }

    /// The lit stars amber, the others its embers.
    private func repaint() {
        for (index, star) in stars.enumerated() {
            let list = pango_attr_list_new()!
            pango_attr_list_insert(list, pango_attr_size_new_absolute(34 * PANGO_SCALE))
            pango_attr_list_insert(list, pango_attr_foreground_new(62_965, 46_530, 18_022))
            let lit = rating >= Double(index) + 1
            pango_attr_list_insert(list, pango_attr_foreground_alpha_new(lit ? 65_535 : 14_418))
            gtk_label_set_attributes(OpaquePointer(star), list)
            pango_attr_list_unref(list)
        }
    }
}

// MARK: - Registration

extension RatingBarWidget {
    /// Adds the bar for `RatingBarContract`, and the act aimed at one bar. Said once, before the application runs.
    @MainActor
    static func register() {
        StateUIControls.add(RatingBarContract.self, create: { reports -> RatingBarWidget in
            let bar = RatingBarWidget()
            // A tapped star is the USER's change: it lands on the state the value is carried in, and raises the event
            // with it.
            bar.onRatingChanged = { rating in
                reports.report(RatingBarContract.rating, rating, as: RatingBarContract.ratingChanged)
            }
            return bar
        }) { bar in
            bar.property(RatingBarContract.rating) { control, rating in
                control.rating = rating ?? 0
            }
            bar.raises(RatingBarContract.ratingChanged)
        }

        // Aimed at one bar: the identity the aim sent is turned back into the control this host made for it.
        StateUIActs.add(RatingBarContract.flash, on: RatingBarWidget.self) { bar in
            bar.flash()
        }
    }
}
