// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Android
import GalleryUI
import StateUIAndroid

/// Stars, as many lit as the rating: the gallery's own Java view, com.stateui.gallery.RatingBarView. A tap sets the
/// rating and reports it; the bar flashes when its act asks.
@MainActor
final class RatingBarView: AndroidControl {
    let view: JavaObject

    /// The user chose a rating.
    var onRatingChanged: ((Double) -> Void)?

    /// Shows `count` stars, `rating` of them lit: the stars first, so a rating stands within them.
    func show(rating: Double, of count: Int) {
        Java.call(view.reference, Self.showing, .double(rating), .int(Int32(count)))
    }

    private let number: Int64

    private static let viewClass = Java.findClass("com/stateui/gallery/RatingBarView")
    private static let make = Java.method(viewClass, "<init>", "(Landroid/content/Context;J)V")
    private static let showing = Java.method(viewClass, "show", "(DI)V")
    private static let flashing = Java.method(viewClass, "flash", "()V")

    init() {
        number = GalleryControls.reserve()
        view = Java.new(Self.viewClass, Self.make, .object(StateUIAndroid.context), .long(number))
        GalleryControls.hold(self, as: number)
    }

    isolated deinit {
        GalleryControls.forget(number)
    }

    /// Fades the bar out and back.
    func flash() {
        Java.call(view.reference, Self.flashing)
    }

    /// The view says its user chose `value`, which it already shows.
    func rated(_ value: Double) {
        onRatingChanged?(value)
    }
}

// listing: InteropActsSample.Android.swift
extension RatingBarView {
    /// Adds the bar for `RatingBarContract`, and the act aimed at it. Said once, as the library loads.
    @MainActor
    static func register() {
        // listing: android.md.applies
        StateUIControls.add(RatingBarContract.self, create: { reports -> RatingBarView in
            let bar = RatingBarView()
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

        // listing: android.md.acts
        // An act aimed at a control is its control's: the identity the aim sent is turned back into the control
        // this host made, and the performer is handed that control.
        StateUIActs.add(RatingBarContract.flash, on: RatingBarView.self) { bar in
            // The Java view fades itself, with its own animate().
            bar.flash()
        }
        // listing: end
    }
}
// listing: end
