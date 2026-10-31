// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
import GalleryUI
import StateUIGTK

/// Stars in a row, as many lit as the rating - a `GtkBox` of labels that knows nothing of StateUI.
///
/// The Swift half is Sources/Samples/Interop/RatingBar.swift; the act aimed at a bar, `flash`, is registered at the
/// end of this file beside the control it flashes.
@MainActor
final class RatingBarWidget: GTKControl {
    let widget: UnsafeMutablePointer<GtkWidget>

    /// The user chose a rating, 1 through the bar's stars.
    var onRatingChanged: ((Double) -> Void)?

    /// How many stars are lit.
    private var rating = 0.0

    /// Shows `count` stars, `rating` of them lit: the stars first, so a rating stands within them.
    func show(rating: Double, of count: Int) {
        let count = max(count, 1)
        let box = UnsafeMutablePointer<GtkBox>(OpaquePointer(widget))
        while stars.count > count { gtk_box_remove(box, stars.removeLast()) }
        while stars.count < count {
            let star = gtk_label_new("★")!
            gtk_box_append(box, star)
            stars.append(star)
        }
        self.rating = min(max(rating, 0), Double(count))
        repaint()
    }

    private var stars: [UnsafeMutablePointer<GtkWidget>] = []
    private let click: OpaquePointer
    private var flashing: UnsafeMutablePointer<AdwAnimation>?

    /// Five labels in a box, and ONE click gesture on the row, the star read from the click's position.
    init() {
        widget = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6)
        g_object_ref_sink(widget)

        click = gtk_gesture_click_new()
        let released: @convention(c) (OpaquePointer?, Int32, Double, Double, gpointer?) -> Void = { _, _, x, _, data in
            MainActor.assumeIsolated {
                Unmanaged<RatingBarWidget>.fromOpaque(data!).takeUnretainedValue().clicked(x: x)
            }
        }
        g_signal_connect_data(
            UnsafeMutableRawPointer(click), "released", unsafeBitCast(released, to: GCallback.self),
            Unmanaged.passUnretained(self).toOpaque(), nil, GConnectFlags(rawValue: 0))
        gtk_widget_add_controller(widget, click)
        show(rating: 0, of: 5)
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
        let chosen = Double(min(max(Int(x / (width / Double(stars.count))), 0), stars.count - 1) + 1)
        rating = chosen
        repaint()
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

// listing: InteropActsSample.GTK.swift
extension RatingBarWidget {
    /// Adds the bar for `RatingBarContract`, and the act aimed at one bar. Said once, before the application runs.
    @MainActor
    static func register() {
        // listing: end
        // listing: gtk.md.applies
        StateUIControls.add(RatingBarContract.self, create: { reports -> RatingBarWidget in
            let bar = RatingBarWidget()
            // A tapped star is the USER's change: it lands on the state the value is carried in, and raises the event
            // with it.
            bar.onRatingChanged = { rating in
                reports.report(RatingBarContract.rating, rating, as: RatingBarContract.ratingChanged)
            }
            return bar
        }) { bar in
            // The stars and the rating come together: a rating stands within the stars, whichever of the two changed.
            bar.applies(RatingBarContract.maximum, RatingBarContract.rating) { control, values in
                control.show(
                    rating: values[RatingBarContract.rating] ?? 0, of: Int(values[RatingBarContract.maximum] ?? 5))
            }
            bar.raises(RatingBarContract.ratingChanged)
        }
        // listing: end

        // listing: InteropActsSample.GTK.swift
        // listing: gtk.md.acts
        // Aimed at one bar: the identity the aim sent is turned back into the control this host made for it.
        // The performer is handed that control, and flash() dims it and brings it back with libadwaita's animation.
        StateUIActs.add(RatingBarContract.flash, on: RatingBarWidget.self) { bar in
            bar.flash()
        }
        // listing: end
    }
}
// listing: end
