// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import GalleryUI
import StateUIUIKit
import UIKit

/// Stars, filled up to a rating - an ordinary `UIView` with two values.
///
/// `register()`, at the end of this file, adds it for `RatingBarContract` with
/// its stars and its rating taken together, so the host assigns them whenever
/// a patch carries either, a style sets them, and a state walks the rating -
/// and performs the `flash` act aimed at one bar.
/// The Swift half is Sources/Samples/Interop/RatingBar.swift.
final class RatingBarView: UIView {
    /// The rating changed - a tap on a star. An assignment the host makes, on
    /// a render or on a walked frame, is not reported: the control is showing
    /// what it was told, not deciding.
    var onRatingChanged: ((Double) -> Void)?

    /// How many stars are filled, 0 through the bar's stars. A fraction fills a
    /// star once the value reaches it, which is what a walk shows star by star.
    private(set) var rating: Double = 0

    /// Shows `count` stars, `rating` of them filled: the stars first, so a
    /// rating stands within them.
    func show(rating: Double, of count: Int) {
        let count = max(count, 1)
        if count != stars.count {
            stars.forEach { $0.removeFromSuperview() }
            stars = (0..<count).map { _ in Self.star() }
            stars.forEach(addSubview)
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
        self.rating = min(max(rating, 0), Double(count))
        repaint()
    }

    private static let lit = UIColor(red: 0.961, green: 0.710, blue: 0.275, alpha: 1)
    private static let ember = UIColor(red: 0.961, green: 0.710, blue: 0.275, alpha: 0.22)
    private static let spacing: CGFloat = 6
    private static let size: CGFloat = 34

    private var stars: [UILabel] = []

    /// Five stars, wired once.
    init() {
        super.init(frame: .zero)
        show(rating: 0, of: 5)

        // ONE recognizer on the row, the star read from the tap's position:
        // a recognizer per star would have to be kept in step with the layout,
        // and the position needs nothing kept at all.
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
        repaint()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("RatingBarView is created in code")
    }

    /// One star, its words at the bar's size.
    private static func star() -> UILabel {
        let star = UILabel()
        star.text = "★"
        star.font = .systemFont(ofSize: size)
        star.textAlignment = .center
        return star
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let star = stars.first?.intrinsicContentSize ?? CGSize(width: Self.size, height: Self.size)
        let count = CGFloat(stars.count)
        return CGSize(width: star.width * count + Self.spacing * (count - 1), height: star.height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let width = (bounds.width - Self.spacing * CGFloat(stars.count - 1)) / CGFloat(stars.count)

        for (index, star) in stars.enumerated() {
            star.frame = CGRect(x: CGFloat(index) * (width + Self.spacing), y: 0, width: width, height: bounds.height)
        }
    }

    /// Fades the bar and back - what the aimed act performs.
    func flash() {
        UIView.animate(withDuration: 0.12) {
            self.alpha = 0.25
        } completion: { _ in
            UIView.animate(withDuration: 0.12) { self.alpha = 1 }
        }
    }

    /// Which star the tap landed on, reported as the rating it gives.
    @objc private func tapped(_ recognizer: UITapGestureRecognizer) {
        guard bounds.width > 0 else { return }

        let at = recognizer.location(in: self)
        let star = Int(at.x / (bounds.width / CGFloat(stars.count)))
        let chosen = Double(min(max(star, 0), stars.count - 1) + 1)

        rating = chosen
        repaint()
        onRatingChanged?(chosen)
    }

    /// Stars up to the rating lit, the rest embers.
    private func repaint() {
        for (index, star) in stars.enumerated() {
            star.textColor = rating >= Double(index) + 1 ? Self.lit : Self.ember
        }
    }
}

// MARK: - Registration

// listing: InteropActsSample.UIKit.swift
extension RatingBarView {
    /// Adds the bar for `RatingBarContract`, and performs the act aimed at
    /// one. Said once, before the application runs.
    @MainActor
    static func register() {
        // listing: end
        // The bar, added for its contract: its stars and its rating put on it together, a tapped star reported.
        StateUIControls.add(RatingBarContract.self, create: { reports -> RatingBarView in
            let bar = RatingBarView()

            // A tapped star is the USER's change: it lands on the state the
            // value is carried in, and raises the event with it - so an
            // application hears it once, whether it holds the rating in a
            // state or in a handler.
            bar.onRatingChanged = { rating in
                reports.report(RatingBarContract.rating, rating, as: RatingBarContract.ratingChanged)
            }
            return bar
        }) { bar in
            // The stars and the rating come together: a rating stands within
            // the stars, whichever of the two changed.
            bar.applies([RatingBarContract.maximum, RatingBarContract.rating]) { view, values in
                view.show(
                    rating: values[RatingBarContract.rating] ?? 0,
                    of: Int(values[RatingBarContract.maximum] ?? 5))
            }
            bar.raises(RatingBarContract.ratingChanged)
        }

        // listing: InteropActsSample.UIKit.swift
        // Aimed at one bar: the identity the aim sent is turned back into the
        // view this host made, and the performer is handed that view.
        StateUIActs.add(RatingBarContract.flash, on: RatingBarView.self) { bar in
            bar.flash()
        }
    }
}
// listing: end
