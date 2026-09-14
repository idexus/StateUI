#if MAUI
// The Swift half of the C# RatingBar, shared by the samples that call, bind,
// style and animate it. The C# class is Platforms/Maui/Host/RatingBar.cs, and
// Platforms/Maui/Host/MauiProgram.cs registers it.

import StateUI

extension NodeType {
    /// The C# RatingBar, registered under this name.
    static let ratingBar = NodeType("Gallery.RatingBar")
}

extension Prop {
    /// How many stars are filled. C#: `RatingBar.RatingProperty`, declared in
    /// the registration, so the host assigns it, walks it and lets a style
    /// set it.
    static let rating = Prop("rating")
}

extension Event {
    /// A star was tapped. C#: `RatingBar.RatingChanged`. A value this side
    /// assigns - described, styled or walked - never comes back as this
    /// event.
    static let ratingChanged = Event("ratingChanged")
}

/// The RatingBar's own properties. The control wears them and so does its
/// style, so each setter is written once.
protocol RatingBarProperties: PropertyContainer {}

extension RatingBarProperties {
    /// How many stars are filled, 0 through 5. C#: `RatingBar.Rating`.
    func rating(_ value: Double) -> Modified {
        setValue(.rating, .number(value))
    }
}

/// Five stars drawn by a control written in C#, described here like a
/// built-in one.
struct RatingBar: View, RatingBarProperties {
    var node = Node(type: .ratingBar)

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
        setValue(.rating, on: state, mode: .inOut, kind: .property)
    }

    /// A star was tapped, with the rating it gave. Runs beside a binding's
    /// write-back, never instead of it.
    func onRatingChanged(_ handler: @escaping ValueEventHandler<Double>) -> Self {
        onEvent(.ratingChanged) { payload in
            if let rating = payload.value()?.number {
                try await handler(rating)
            }
        }
    }
}

/// A style can target the bar: a style target is a control with an empty
/// initializer, and a style resolves by the node type `RatingBar()` makes.
extension RatingBar: StyleTarget {}

/// A style of the bar offers the bar's own setters.
extension StyleBag: RatingBarProperties where Target == RatingBar {}
#endif
