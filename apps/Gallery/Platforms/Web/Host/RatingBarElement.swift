// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import GalleryUI
import StateUIWeb

/// Stars in a row, as many lit as the rating: the gallery's own element, `<gallery-rating-bar>` of
/// Page/rating-bar.js, which knows nothing of StateUI.
///
/// The Swift half is Sources/Samples/Interop/RatingBar.swift; the act aimed at a bar, `flash`, is registered at the
/// end of this file.
@MainActor
final class RatingBarElement: WebControl {
    let element = WebPageElement(tag: "gallery-rating-bar")

    /// The user chose a rating, 1 through the bar's stars.
    var onRatingChanged: ((Double) -> Void)?

    init() {
        show(rating: 0, of: 5)
        element.listen("ratingchange", number: { [weak self] chosen in self?.onRatingChanged?(chosen) })
    }

    /// Shows `count` stars, `rating` of them lit: the stars first, so a rating stands within them.
    func show(rating: Double, of count: Int) {
        let count = max(count, 1)
        element.setAttribute("stars", String(count))
        element.setAttribute("rating", String(min(max(rating, 0), Double(count))))
    }

    // listing: InteropActsSample.Web.swift
    /// Dims the bar and brings it back: the element's own animation of its opacity.
    func flash() {
        element.call("flash")
    }
    // listing: end
}

// MARK: - Registration

extension RatingBarElement {
    /// Adds the bar for `RatingBarContract`, and the act aimed at one bar. Said once, before the application runs.
    static func register() {
        StateUIControls.add(RatingBarContract.self, create: { reports -> RatingBarElement in
            let bar = RatingBarElement()
            // A tapped star is the USER's change: it lands on the state the value is carried in, and raises the event
            // with it.
            bar.onRatingChanged = { rating in
                reports.report(RatingBarContract.rating, rating, as: RatingBarContract.ratingChanged)
            }
            return bar
        }) { bar in
            // The stars and the rating come together: a rating stands within the stars, whichever of the two changed.
            bar.applies([RatingBarContract.maximum, RatingBarContract.rating]) { control, values in
                control.show(
                    rating: values[RatingBarContract.rating] ?? 0, of: Int(values[RatingBarContract.maximum] ?? 5))
            }
            bar.raises(RatingBarContract.ratingChanged)
        }

        // listing: InteropActsSample.Web.swift
        // Aimed at one bar: the identity the aim sent is turned back into the control this host made for it.
        StateUIActs.add(RatingBarContract.flash, on: RatingBarElement.self) { bar in
            bar.flash()
        }
        // listing: end
    }
}
