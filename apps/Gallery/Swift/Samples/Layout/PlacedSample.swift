import Foundation
import StateUI

/// A layout of the author's own: one line of arithmetic says where each card
/// goes, and every card travels there.
struct PlacedSample: SampleContent {
    static let id = "placed"
    static let title = "A layout of your own"
    static let summary = "Placed hands you the index, the count and the room, and takes a rectangle back - a fan, a ring or a row, and the cards fly between them."

    /// The three arrangements the same eight cards are put in.
    static let shapes = ["Fan", "Ring", "Row"]

    @State private var shape = 0
    @State private var cards = [1, 2, 3, 4, 5, 6]
    @State private var next = 7

    static let code = """
        @State private var shape = 0
        @State private var cards = [1, 2, 3, 4, 5, 6]

        // THE WHOLE LAYOUT IS THIS CLOSURE. Given which card this is, how many
        // there are and how much room there is, it answers where the card goes.
        // Nothing here says "animate": a card given a new place travels to it,
        // so changing the shape flies every card across at once.
        Placed(cards, id: \\.self, at: { index, count, room in
            let middle = Double(index) - Double(count - 1) / 2

            switch shape {
            case 1:
                let angle = Double(index) / Double(count) * 2 * .pi
                let radius = min(room.width, room.height) / 2 - 46
                return Rect(
                    room.width / 2 + cos(angle) * radius - 32,
                    room.height / 2 + sin(angle) * radius - 32,
                    64,
                    64)
            case 2:
                let step = min(84, room.width / Double(count))
                return Rect(room.width / 2 + middle * step - 32, room.height / 2 - 32, 64, 64)
            default:
                return Rect(
                    room.width / 2 + middle * 40 - 32,
                    room.height / 2 + middle * middle * 7 - 32,
                    64,
                    64)
            }
        }) { card in
            Border { Label("\\(card)") }
        }
        """

    var content: Element {
        VStack {
            Placed(cards, id: \.self, at: place) { card in
                Border {
                    Label("\(card)")
                        .fontSize(20)
                        .fontAttributes(.bold)
                        .textColor(Palette.onBrand)
                        .horizontalOptions(.center)
                        .verticalOptions(.center)
                }
                .backgroundColor(card % 2 == 0 ? Palette.brand : Palette.accent)
                .strokeThickness(0)
                .strokeShape(.roundRectangle(14))
            }
            .heightRequest(260)

            HStack {
                Button(Self.shapes[shape]).onClicked {
                    shape = (shape + 1) % Self.shapes.count
                }

                Button("Add").onClicked {
                    cards.append(next)
                    next += 1
                }

                Button("Remove").onClicked {
                    if cards.count > 1 { cards.removeLast() }
                }
            }
            .spacing(8)
        }
        .spacing(10)
    }

    /// Where one card goes - the whole of the layout.
    private func place(_ index: Int, _ count: Int, _ room: Rect) -> Rect {
        let middle = Double(index) - Double(count - 1) / 2

        switch shape {
        case 1:
            let angle = Double(index) / Double(count) * 2 * .pi
            let radius = min(room.width, room.height) / 2 - 46

            return Rect(
                room.width / 2 + cos(angle) * radius - 32,
                room.height / 2 + sin(angle) * radius - 32,
                64,
                64)

        case 2:
            let step = min(84, room.width / Double(max(count, 1)))

            return Rect(
                room.width / 2 + middle * step - 32,
                room.height / 2 - 32,
                64,
                64)

        default:
            return Rect(
                room.width / 2 + middle * 40 - 32,
                room.height / 2 + middle * middle * 7 - 32,
                64,
                64)
        }
    }

    var notes: Element? {
        VStack {
            Label("A fan, a ring and a row are the same six cards under three "
                + "lines of arithmetic. `Placed` hands the closure which card it "
                + "is, how many there are and the room it has, and takes back a "
                + "rectangle - that is the whole layout, and no toolkit ships any "
                + "of these three.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("Change the shape and every card FLIES to its new place: a "
                + "placement is a value like any other, so where a card sits is "
                + "somewhere it travels to. Add a card and the fan spreads to "
                + "make room; remove one and it closes up again.")
                .fontSize(13)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
