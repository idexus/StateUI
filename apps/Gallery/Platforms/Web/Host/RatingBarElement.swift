// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import GalleryUI
import StateUIWeb

/// Five stars in a row, as many lit as the rating: the gallery's own element, `<gallery-rating-bar>` of
/// Page/rating-bar.js, which knows nothing of StateUI.
///
/// The Swift half is Sources/Samples/Interop/RatingBar.swift; the act aimed at a bar, `flash`, is registered at the
/// end of this file.
@MainActor
final class RatingBarElement: WebControl {
    let element = WebPageElement(tag: "gallery-rating-bar")

    /// The user chose a rating, 1 through 5.
    var onRatingChanged: ((Double) -> Void)?

    /// How many stars are lit.
    var rating = 0.0 {
        didSet { if rating != oldValue { element.setAttribute("rating", String(rating)) } }
    }

    init() {
        element.setAttribute("rating", String(rating))
        element.listen("ratingchange") { [weak self] (chosen: Double) in
            guard let self else { return }
            rating = chosen
            onRatingChanged?(chosen)
        }
    }

    /// Dims the bar and brings it back: the element's own animation of its opacity.
    func flash() {
        element.call("flash")
    }
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
            bar.property(RatingBarContract.rating) { control, rating in
                control.rating = rating ?? 0
            }
            bar.raises(RatingBarContract.ratingChanged)
        }

        // Aimed at one bar: the identity the aim sent is turned back into the control this host made for it.
        StateUIActs.add(RatingBarContract.flash, on: RatingBarElement.self) { bar in
            bar.flash()
        }
    }
}
