#if MAUI
import StateUI

/// A registered control handed a state with `$`: the host shows the state,
/// and a tapped star lands on it. The RatingBar is in RatingBar.swift.
struct CustomBindingSample: SampleContent, ExampleContent {
    @State private var stars = 3.0

    static let id = "customBinding"
    static let title = "Binding a C# value"
    static let summary = "A registered control handed a state with $ - shown, and written back on a tap."

    static let code = """
        enum RatingBarContract: ElementContract {
            static let nodeType: NodeType = "Gallery.RatingBar"
            static let tiers: [any Contract.Type] = [ViewContract.self]

            static let rating = ElementProperty<Self, Double>("rating")
            static let ratingChanged = ElementEvent<Self, Double>("ratingChanged")
            static let flash = ElementAct<Self, Void, Void>("Gallery.FlashRating")

            static let members: [any ContractMember] = [rating, ratingChanged, flash]
        }

        protocol RatingBarProperties: PropertyContainer {}

        extension RatingBarProperties {
            func rating(_ value: Double) -> Modified {
                setValue(RatingBarContract.rating, value)
            }
        }

        struct RatingBar: View, RatingBarProperties {
            var node = Node(contract: RatingBarContract.self)

            init() {}

            // Handed over: the host walks the property from the state, and a
            // tapped star snaps the state to it.
            init(_ rating: Binding<Double>) {
                self = RatingBar()
                    .rating(rating)
                    .onRatingChanged { rating.journey.snap(to: $0) }
            }

            func rating(_ state: Binding<Double>) -> Modified {
                setValue(RatingBarContract.rating, on: state, mode: .inOut, kind: .property)
            }

            func onRatingChanged(_ handler: @escaping ValueEventHandler<Double>) -> Self {
                onEvent(RatingBarContract.ratingChanged, handler)
            }
        }

        @State private var stars = 3.0

        VStack {
            // The caption reads `stars`, so a tap and Clear build this closure.
            DebugInfoLabel()

            RatingBar($stars)

            Label("you gave \\(Int(stars)) of 5")

            // An assignment travels the stars there.
            Button("Clear")
                .onClicked { stars = 0 }
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            RatingBar($stars)
                .horizontalAlignment(.center)

            Label("you gave \(Int(stars)) of 5")
                .fontSize(17)
                .horizontalTextAlignment(.center)

            Button("Clear")
                .onClicked { stars = 0 }
        }
        .spacing(8)
    }

    var notes: Element? {
        VStack {
            Label("`RatingBar($stars)` hands the state to the host: `.rating($stars)` "
                + "walks the declared `RatingProperty` from it, and the view writing that "
                + "line reads nothing.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A tap comes back as the control's `ratingChanged` event, and the "
                + "binding's write-back snaps the state to the tapped star - it is "
                + "already on screen, so nothing travels. A value the host assigns, on "
                + "a render or on a walked frame, never comes back as a tap.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Clear is an assignment, and an assignment travels: the stars empty "
                + "on the host's frames while the caption says 0 at once.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
#endif
