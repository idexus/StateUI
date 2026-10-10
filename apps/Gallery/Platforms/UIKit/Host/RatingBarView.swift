// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import GalleryUI
import StateUIUIKit
import UIKit

/// Five stars, filled up to a rating - an ordinary `UIView` with one value.
///
/// `register()`, at the end of this file, adds it for `RatingBarContract` with
/// `rating`, so the host assigns it whenever a patch carries it, a style sets
/// it, and a state walks it - and performs the `flash` act aimed at one bar.
/// The Swift half is Sources/Samples/Interop/RatingBar.swift.
final class RatingBarView: UIView {
    /// The rating changed - a tap on a star. An assignment the host makes, on
    /// a render or on a walked frame, is not reported: the control is showing
    /// what it was told, not deciding.
    var onRatingChanged: ((Double) -> Void)?

    /// How many stars are filled, 0 through 5. A fraction fills a star once
    /// the value reaches it, which is what a walk shows star by star.
    var rating: Double = 0 {
        didSet { if rating != oldValue { repaint() } }
    }

    private static let lit = UIColor(red: 0.961, green: 0.710, blue: 0.275, alpha: 1)
    private static let ember = UIColor(red: 0.961, green: 0.710, blue: 0.275, alpha: 0.22)
    private static let spacing: CGFloat = 6
    private static let size: CGFloat = 34

    private var stars: [UILabel] = []

    /// The five stars, wired once.
    init() {
        super.init(frame: .zero)

        for _ in 0..<5 {
            let star = UILabel()
            star.text = "★"
            star.font = .systemFont(ofSize: Self.size)
            star.textAlignment = .center
            addSubview(star)
            stars.append(star)
        }

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

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let star = stars.first?.intrinsicContentSize ?? CGSize(width: Self.size, height: Self.size)
        return CGSize(width: star.width * 5 + Self.spacing * 4, height: star.height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let width = (bounds.width - Self.spacing * 4) / 5

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
        let star = Int(at.x / (bounds.width / 5))
        let chosen = Double(min(max(star, 0), 4) + 1)

        rating = chosen
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
        // The bar, added for its contract: its rating put on it, a tapped star reported.
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
            bar.property(RatingBarContract.rating) { view, rating in
                view.rating = rating ?? 0
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
