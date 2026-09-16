// A control of the application's OWN, declared once for every host that
// realizes it - shared by the samples that call, bind, style and animate it.
//
// This file is the whole Swift half, and it is the same wherever the gallery
// runs. What the bar IS on screen each host says for itself, in
// Platforms/AppKit/Host and Platforms/Maui/Host.

import StateUI

/// The gallery's own rating bar, declared: its node type, the tier it wears,
/// and its members, each with its value's type.
enum RatingBarContract: ElementContract {
    static let nodeType: NodeType = "Gallery.RatingBar"
    static let tiers: [any Contract.Type] = [ViewContract.self]

    /// How many stars are filled. Declared by every host's registration, so
    /// the host assigns it, walks it and lets a style set it.
    static let rating = ElementProperty<Self, Double>("rating")

    /// A star was tapped. A value this side assigns - described, styled or
    /// walked - never comes back as this event.
    static let ratingChanged = ElementEvent<Self, Double>("ratingChanged")

    /// Draws attention to one bar: the performer the aim reaches fades the
    /// view it is aimed at.
    static let flash = ElementAct<Self, Void, Void>("Gallery.FlashRating")

    static let members: [any ContractMember] = [rating, ratingChanged, flash]
}

/// The RatingBar's own properties. The control wears them and so does its
/// style, so each setter is written once.
protocol RatingBarProperties: PropertyContainer {}

extension RatingBarProperties {
    /// How many stars are filled, 0 through 5.
    func rating(_ value: Double) -> Modified {
        setValue(RatingBarContract.rating, value)
    }
}

/// Five stars drawn by a control the application registered with its host,
/// described here like a built-in one.
struct RatingBar: View, RatingBarProperties {
    var node = Node(contract: RatingBarContract.self)

    /// An empty bar: the value set with `.rating(_:)`, a tap heard with
    /// `.onRatingChanged(_:)`.
    init() {}

    /// Two-way: shows the state and lands a tapped star on it.
    ///
    ///     @State private var stars = 3.0
    ///
    ///     RatingBar($stars)
    ///
    /// The state is handed to the host, which walks the property from it, so
    /// the view writing this line is not a reader of it. A tap reaches Swift
    /// as `ratingChanged`, and the write-back snaps the state to it: the
    /// control already shows the tapped star, so nothing travels. An
    /// assignment - `stars = 0` - travels the stars there.
    ///
    /// The write-back is an event handler because a change the control makes
    /// itself reaches Swift only as its event.
    init(_ rating: Binding<Double>) {
        self = RatingBar()
            .rating(rating)
            .onRatingChanged { rating.journey.snap(to: $0) }
    }

    /// How many stars are filled, walked by the host from a state.
    ///
    ///     try await $stars.journey.move(to: 5, .eased(1200))
    ///
    /// `.inOut`, because the host reports where the walk has got to, which is
    /// what `$stars.journey.value` reads. A tap does not arrive this way;
    /// `.onRatingChanged(_:)` hears it.
    ///
    /// On the control and not on `RatingBarProperties`: a style wears that
    /// protocol, and a style has no state to follow.
    func rating(_ state: Binding<Double>) -> Modified {
        setValue(RatingBarContract.rating, on: state, mode: .inOut, kind: .property)
    }

    /// A star was tapped, with the rating it gave. Runs beside a binding's
    /// write-back, never instead of it.
    func onRatingChanged(_ handler: @escaping ValueEventHandler<Double>) -> Self {
        onEvent(RatingBarContract.ratingChanged, handler)
    }
}

/// An act of the bar's contract, aimed at one bar.
///
/// `call` puts the control's identity in argument 0, and the host half turns
/// it back into the control it made. Two bars on one page each answer to
/// their own aim.
extension Aim where Target == RatingBar {
    /// Flashes the bar this aim is on.
    func flash() async throws {
        try await call(RatingBarContract.flash)
    }
}

/// A style can target the bar: a style target is a control with an empty
/// initializer, and a style resolves by the node type `RatingBar()` makes.
extension RatingBar: StyleTarget {}

/// A style of the bar offers the bar's own setters.
extension StyleBag: RatingBarProperties where Target == RatingBar {}
