// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CGalleryWinUI
import GalleryUI
import StateUIWinUI

/// Five stars the user picks from - WinUI's own RatingControl, made by the gallery's relay - and a flash an aimed act
/// asks for.
///
/// `register()`, at the end of this file, adds it for `RatingBarContract` and performs `flash`. The Swift half is
/// Sources/Samples/Interop/RatingBar.swift.
@MainActor
final class RatingBarControl: WinUIControl {
    let element: OpaquePointer

    /// The user chose a rating. A rating the tree writes is told to no one.
    var onRatingChanged: ((Double) -> Void)?

    /// How many stars are lit.
    var rating = 0.0 {
        didSet { if rating != oldValue { gallery_rating_bar_set_rating(element, rating) } }
    }

    private let number: Int64

    init() {
        number = GalleryControls.reserve()
        element = gallery_rating_bar_make(number)!
        GalleryControls.hold(self, as: number)
    }

    isolated deinit {
        GalleryControls.forget(number)
        gallery_winui_release(element)
    }

    /// The relay says the user chose `value`.
    func rated(_ value: Double) {
        rating = value
        onRatingChanged?(value)
    }

    /// Fades the bar down and back, twice.
    func flash() {
        gallery_rating_bar_flash(element)
    }
}

// MARK: - Registration

extension RatingBarControl {
    /// Adds the bar for `RatingBarContract`, and performs its aimed `flash`. Said once, before the application runs.
    @MainActor
    static func register() {
        StateUIControls.add(RatingBarContract.self, create: { reports -> RatingBarControl in
            let bar = RatingBarControl()
            bar.onRatingChanged = { rating in
                reports.report(RatingBarContract.rating, rating, as: RatingBarContract.ratingChanged)
            }
            return bar
        }) { bar in
            bar.property(RatingBarContract.rating) { control, rating in control.rating = rating ?? 0 }
            bar.raises(RatingBarContract.ratingChanged)
        }

        // Aimed at one bar: the identity the aim sent is turned back into the control this host made for it.
        StateUIActs.add(RatingBarContract.flash, on: RatingBarControl.self) { bar in
            bar.flash()
        }
    }
}
