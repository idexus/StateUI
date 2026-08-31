import StateUI

// The Swift half of the C# RatingBar - shared by the binding, style and
// animation samples, which all drive the same control. The C# class and its
// registration are in Host/RatingBar.cs and Host/MauiProgram.cs; the IN C#
// listings on those samples show both.

extension NodeType {
    /// The C# RatingBar, registered in MauiProgram under this name.
    static let ratingBar = NodeType("Gallery.RatingBar")
}

extension Prop {
    /// How many stars are filled. C#: RatingBar.RatingProperty - DECLARED in
    /// the registration, so the renderer assigns it, an animation can walk
    /// it, and a style can set it.
    static let rating = Prop("rating")
}

extension Event {
    /// The rating changed - a tapped star, or any assignment.
    /// C#: RatingBar.RatingChanged.
    static let ratingChanged = Event("ratingChanged")
}

/// The RatingBar's own properties, on a protocol - the library's own pattern
/// for a control's property surface: the control conforms on the element
/// side, the style bag on the property side, and the modifier is written
/// ONCE.
protocol RatingBarProperties: PropertyContainer {}

extension RatingBarProperties {
    /// How many stars are filled, 0 through 5. C#: RatingBar.Rating.
    func rating(_ value: Double) -> Modified {
        setValue(.rating, .number(value))
    }
}

/// A registered C# control, spoken to like a built-in - and the BINDING
/// pattern: a control that carries a value the user changes takes a
/// `Binding`, which sets the property and registers the write-back in one
/// place, exactly as `Entry($text)` does. The write-back goes through
/// `onEvent`, which COMPOSES - an `.onRatingChanged` written after the
/// binding runs beside it, never instead of it, the library's own rule.
struct RatingBar: View, RatingBarProperties {
    var node = Node(type: .ratingBar)

    /// An empty bar - the value written with `.rating(_:)`, heard with
    /// `.onRatingChanged(_:)`.
    init() {}

    /// The two-way form: `RatingBar($stars)` shows the value and writes what
    /// the user taps back into it.
    ///
    /// For a value the app means to FLY, write `.rating($state)` instead and
    /// hear the walk with `.onRatingChanged`: this form's write-back is an
    /// assignment to the flying state on every frame, and an assignment to an
    /// armed property is exactly what ENDS a walk.
    init(_ rating: Binding<Double>) {
        self = self
            .rating(rating.wrappedValue)
            .onRatingChanged { rating.wrappedValue = $0 }
    }

    /// How many stars are filled, from the state that MOVES it - the app's own
    /// armed modifier, and the whole of what an app writes to make its control
    /// flyable: `$stars.animateTo(5, .eased(1200))` then walks RatingProperty
    /// the way it walks a Border's opacity.
    ///
    /// On the CONTROL rather than on `RatingBarProperties`, because a
    /// `StyleBag` wears that protocol and a style has no state to arm - the
    /// library's own rule for every armed modifier it has.
    ///
    /// One-way on purpose: what the control REPORTS as it walks belongs in a
    /// state of its own, through `.onRatingChanged`, since writing it back
    /// here would end the flight.
    func rating(_ value: Binding<Double>) -> Modified {
        setValue(.rating, .number(value.wrappedValue), armedOn: value)
    }

    /// The rating changed - a tapped star, or any assignment, an animated
    /// one's every frame included. C#: RatingBar.RatingChanged.
    func onRatingChanged(_ handler: @escaping ValueEventHandler<Double>) -> Self {
        onEvent(.ratingChanged) { payload in
            if let rating = payload.value()?.number {
                try await handler(rating)
            }
        }
    }
}

/// What lets `Style<RatingBar>` exist: a style target is any VisualElement
/// with an empty initializer, and the registration on the C# side knows the
/// class the target type resolves to.
extension RatingBar: StyleTarget {}

/// And the style gets the control's own setters - the one line the library
/// writes per control, written here by the app for its own.
extension StyleBag: RatingBarProperties where Target == RatingBar {}
