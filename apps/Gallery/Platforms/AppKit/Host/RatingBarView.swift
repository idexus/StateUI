// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import AppKit
import GalleryUI
import StateUIAppKit

/// Five stars, filled up to a rating - an ordinary `NSView` with one value.
///
/// `register()`, at the end of this file, adds it for `RatingBarContract` with
/// `rating`, so the host assigns it whenever a message carries it, a style sets
/// it, and a state walks it - and performs the `flash` act aimed at one bar.
/// The Swift half is Sources/Samples/Interop/RatingBar.swift.
final class RatingBarView: NSView {
    /// The rating changed - a tap on a star. An assignment the host makes, on
    /// a render or on a walked frame, is not reported: the control is showing
    /// what it was told, not deciding.
    var onRatingChanged: ((Double) -> Void)?

    /// How many stars are filled, 0 through 5. A fraction fills a star once
    /// the value reaches it, which is what a walk shows star by star.
    var rating: Double = 0 {
        didSet { if rating != oldValue { repaint() } }
    }

    private static let lit = NSColor(srgbRed: 0.961, green: 0.710, blue: 0.275, alpha: 1)
    private static let ember = NSColor(srgbRed: 0.961, green: 0.710, blue: 0.275, alpha: 0.22)
    private static let spacing: CGFloat = 6
    private static let size: CGFloat = 34

    private var stars: [NSTextField] = []

    override var isFlipped: Bool { true }

    /// The five stars, wired once.
    init() {
        super.init(frame: .zero)

        for _ in 0..<5 {
            let star = NSTextField(labelWithString: "★")
            star.font = .systemFont(ofSize: Self.size)
            star.alignment = .center
            addSubview(star)
            stars.append(star)
        }

        // ONE recognizer on the row, the star read from the click's position:
        // a recognizer per star would have to be kept in step with the layout,
        // and the position needs nothing kept at all.
        let click = NSClickGestureRecognizer(target: self, action: #selector(clicked(_:)))
        addGestureRecognizer(click)
        repaint()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("RatingBarView is created in code")
    }

    override var intrinsicContentSize: NSSize {
        let star = stars.first?.intrinsicContentSize ?? NSSize(width: Self.size, height: Self.size)
        return NSSize(
            width: star.width * 5 + Self.spacing * 4,
            height: star.height)
    }

    override func layout() {
        super.layout()

        let width = (bounds.width - Self.spacing * 4) / 5

        for (index, star) in stars.enumerated() {
            star.frame = NSRect(
                x: CGFloat(index) * (width + Self.spacing),
                y: 0,
                width: width,
                height: bounds.height)
        }
    }

    /// Fades the bar and back - what the aimed act performs.
    ///
    /// The completion arrives on the main queue but is not isolated to it, so
    /// the way back is put on the main actor explicitly rather than mutating
    /// the view from a context the compiler cannot vouch for.
    @MainActor
    func flash() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            animator().alphaValue = 0.25
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.12
                    self?.animator().alphaValue = 1
                }
            }
        }
    }

    /// Which star the click landed on, reported as the rating it gives.
    @objc private func clicked(_ recognizer: NSClickGestureRecognizer) {
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

extension RatingBarView {
    /// Adds the bar for `RatingBarContract`, and performs the act aimed at
    /// one. Said once, before the application runs.
    @MainActor
    static func register() {
        StateUIControls.add(RatingBarContract.self, create: { reports -> RatingBarView in
            let bar = RatingBarView()

            // A tapped star is the READER's change: it lands on the state the
            // value is carried in, and raises the event with it - so an
            // application hears it once, whether it holds the rating in a
            // state or in a handler.
            bar.onRatingChanged = { rating in
                reports.report(
                    RatingBarContract.rating, rating, as: RatingBarContract.ratingChanged)
            }
            return bar
        }) { bar in
            bar.property(RatingBarContract.rating) { view, rating in
                view.rating = rating ?? 0
            }
            bar.raises(RatingBarContract.ratingChanged)
        }

        // Aimed at one bar: the identity the aim sent is turned back into the
        // view this host made, and the performer is handed that view.
        StateUIActs.add(RatingBarContract.flash, on: RatingBarView.self) { bar in
            bar.flash()
        }
    }
}
