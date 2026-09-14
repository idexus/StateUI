import StateUI

/// One colour per family, so the three rows read apart at a glance rather than
/// as one long run of identical squares.
private enum Family {
    /// The two chains that differ only in the ORDER they are written in.
    static let order = Palette.accent

    /// The four ways of turning a view.
    static let turn = Palette.brand

    /// The three ways of resizing one.
    static let size = Color(light: AppColors.amber, dark: AppColors.windowYellow)
}

/// A view turned, tipped and scaled after layout, about an anchor it can move.
struct TransformSample: SampleContent, ExampleContent {
    static let id = "transform"
    static let title = "Transforms"
    static let summary = "Turning, tipping and resizing a view after it has been laid out."

    /// Whether the page wears its transforms - one switch over every example,
    /// so throwing it flies the whole page between plain squares and turned,
    /// tipped, grown ones.
    @State private var transformed = true

    static let code = """
        @State private var transformed = true

        VStack {
            // ONE SWITCH over every example below. Each transform is written
            // as a choice between itself and none, so throwing it sends the
            // whole page to its turned, grown self and back - and a changed
            // transform TRAVELS, so the boxes fly rather than jump.
            SwitchRow("Transforms", $transformed)

            // A GET IN THESE BRACES, which is what makes THIS row a reader:
            // it is built again on every throw, and its count is what that
            // costs. Each row of boxes below reads the switch in its own
            // braces, so each of them is a reader of its own.
            HStack {
                Label(transformed ? "every transform on" : "plain squares")

                DebugInfoLabel()
            }

            // ONE TRANSFORM, in the order it is written: the same two parts,
            // and the move lands somewhere else - written after the turn it
            // is a plain move right, written before it is swung round by it.
            HStack {
                box(Family.order)
                    .transform(transformed ? .rotate(45).translate(28, 0) : .identity)

                box(Family.order)
                    .transform(transformed ? .translate(28, 0).rotate(45) : .identity)
            }

            HStack {
                // Flat, in the plane of the screen.
                box(Family.turn)
                    .rotation(transformed ? 20 : 0)

                // Tipped about the horizontal axis: the top goes away.
                box(Family.turn)
                    .rotationX(transformed ? 55 : 0)

                // Turned about the vertical axis: one side goes away.
                box(Family.turn)
                    .rotationY(transformed ? 55 : 0)

                // The same turn about the top left corner instead of the
                // middle, which is what an anchor moves.
                box(Family.turn)
                    .rotation(transformed ? 20 : 0)
                    .pivotX(0)
                    .pivotY(0)
            }

            // A WIDER GAP than the rows above: a scaled box is drawn outside
            // the room the layout gave it, so the spacing has to leave what
            // it grows into or the three of them touch.
            HStack {
                // Drawing only - the room the layout gave it does not change.
                box(Family.size)
                    .scale(transformed ? 1.6 : 1)

                // The same factor sideways only: wider, and no taller.
                box(Family.size)
                    .scaleX(transformed ? 1.6 : 1)

                // And the other axis on its own: taller, and no wider.
                box(Family.size)
                    .scaleY(transformed ? 1.6 : 1)
            }
            .spacing(44)
        }

        func box(_ colour: Color) -> BoxView {
            BoxView(colour)
                .width(44)
                .height(44)
        }

        /// One colour per family, so the three rows read apart at a glance.
        private enum Family {
            /// The two chains that differ only in the ORDER they are written in.
            static let order = Palette.accent

            /// The four ways of turning a view.
            static let turn = Palette.brand

            /// The three ways of resizing one.
            static let size = Color(light: AppColors.amber, dark: AppColors.windowYellow)
        }
        """

    var content: any View {
        VStack {
            SwitchRow("Transforms", $transformed)

            // A GET IN THESE BRACES, which is what makes THIS row a reader:
            // it is built again on every throw, and its count is what that
            // costs. Each row of boxes below reads the switch in its own
            // braces, so each of them is a reader of its own.
            HStack {
                Label(transformed ? "every transform on" : "plain squares")
                    .fontSize(12)
                    .textColor(Palette.subtle)
                    .verticalAlignment(.center)

                DebugInfoLabel()
            }
            .spacing(10)
            .horizontalAlignment(.center)

            // The same two parts in both chains; only the order differs, so
            // the only thing the row shows is that order is what a chain MEANS.
            HStack {
                piece(
                    box(Family.order)
                        .transform(transformed ? .rotate(45).translate(28, 0) : .identity),
                    "rotate, then move")

                piece(
                    box(Family.order)
                        .transform(transformed ? .translate(28, 0).rotate(45) : .identity),
                    "move, then rotate")
            }
            .spacing(44)
            .horizontalAlignment(.center)

            HStack {
                piece(box(Family.turn).rotation(transformed ? 20 : 0), "rotation")
                piece(box(Family.turn).rotationX(transformed ? 55 : 0), "rotationX")
                piece(box(Family.turn).rotationY(transformed ? 55 : 0), "rotationY")
                piece(
                    box(Family.turn)
                        .rotation(transformed ? 20 : 0)
                        .pivotX(0)
                        .pivotY(0),
                    "anchor 0,0")
            }
            .spacing(24)
            .horizontalAlignment(.center)

            // The same square and the same factor three times, so the only
            // thing the row shows is which axis each modifier reaches - and a
            // WIDER GAP than the violet row, because a scaled box is drawn
            // outside its room and would otherwise touch its neighbours.
            HStack {
                piece(box(Family.size).scale(transformed ? 1.6 : 1), "scale")
                piece(box(Family.size).scaleX(transformed ? 1.6 : 1), "scaleX")
                piece(box(Family.size).scaleY(transformed ? 1.6 : 1), "scaleY")
            }
            .spacing(44)
            .horizontalAlignment(.center)
        }
        .spacing(22)
    }

    var notes: Element? {
        VStack {
            Label("One switch throws every example on the page at once. Each transform is "
                + "written as a choice between itself and none, and a changed transform "
                + "travels - so the boxes fly to their turned, tipped, grown selves and back.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`.transform(_:)` is one transform in the order it is written, about the "
                + "view's centre: `.rotate(45).translate(28, 0)` moves the turned box a plain "
                + "28 to the right, while `.translate(28, 0).rotate(45)` swings that move "
                + "round with the turn. That is the orange row.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`rotation` turns a view within the plane of the screen, so a square stays "
                + "square; `rotationX` and `rotationY` tip it out of that plane, so it becomes "
                + "a trapezium. All of them pivot about the anchor, the middle until it is "
                + "moved: 0 is the left edge or the top, 1 the right edge or the bottom. The "
                + "fourth violet box turns about its top left corner.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A transform happens after the layout: the view keeps the room it was "
                + "given, and only what is drawn moves. `scale` is both axes at once and "
                + "`scaleX` and `scaleY` one each; all three multiply the size the layout "
                + "gave, so 1 is that size and 0.5 half of it. A scaled view overlaps its "
                + "neighbour without pushing it aside, which is why the amber row is spaced "
                + "wider than the violet one.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }

    /// The square every example transforms - sized here, because a transform
    /// is about what is DRAWN and the room each one gets has to be the same.
    ///
    /// - Parameter colour: which family this square belongs to.
    /// - Returns: the square, ready to be transformed.
    private func box(_ colour: Color) -> BoxView {
        BoxView(colour)
            .width(44)
            .height(44)
    }

    /// One piece with its caption, so a row reads as labelled examples rather
    /// than bare boxes. The gap under the box is what a scaled one grows into.
    private func piece(_ view: Element, _ caption: String) -> any View {
        VStack {
            view

            Label(caption)
                .fontSize(11)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)
        }
        .spacing(22)
    }
}
