// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CGalleryWinUI
import GalleryUI
import StateUIWinUI

/// Stars the user picks from - WinUI's own RatingControl, made by the gallery's relay - and a flash an aimed act asks
/// for.
///
/// `register()`, at the end of this file, adds it for `RatingBarContract` and performs `flash`. The Swift half is
/// Sources/Samples/Interop/RatingBar.swift.
@MainActor
final class RatingBarControl: WinUIControl {
    let element: OpaquePointer

    /// The user chose a rating. A rating the tree writes is told to no one.
    var onRatingChanged: ((Double) -> Void)?

    /// Shows `count` stars, `rating` of them lit: the stars first, so a rating stands within them.
    func show(rating: Double, of count: Int) {
        gallery_rating_bar_set_maximum(element, Int32(max(count, 1)))
        gallery_rating_bar_set_rating(element, min(max(rating, 0), Double(max(count, 1))))
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
        onRatingChanged?(value)
    }

    /// Fades the bar down and back, twice.
    func flash() {
        gallery_rating_bar_flash(element)
    }
}

// MARK: - Registration

// listing: InteropActsSample.WinUI.swift
extension RatingBarControl {
    /// Adds the bar for `RatingBarContract`, and performs its aimed `flash`. Said once, before the application runs.
    @MainActor
    static func register() {
// listing: end
        // The bar, made once per element, reporting the rating its user chooses; its stars and its rating taken together.
        StateUIControls.add(RatingBarContract.self, create: { reports -> RatingBarControl in
            let bar = RatingBarControl()
            bar.onRatingChanged = { rating in
                reports.report(RatingBarContract.rating, rating, as: RatingBarContract.ratingChanged)
            }
            return bar
        }) { bar in
            bar.applies([RatingBarContract.maximum, RatingBarContract.rating]) { control, values in
                control.show(
                    rating: values[RatingBarContract.rating] ?? 0, of: Int(values[RatingBarContract.maximum] ?? 5))
            }
            bar.raises(RatingBarContract.ratingChanged)
        }

        // listing: InteropActsSample.WinUI.swift
        // Aimed at one bar: the identity the aim sent is turned back into the control this host made for it.
        StateUIActs.add(RatingBarContract.flash, on: RatingBarControl.self) { bar in
            // A Storyboard in the relay fades the bar's opacity down and back, twice.
            bar.flash()
        }
    }
}
// listing: end
