import StateUI

/// A subtree that is not rebuilt while its input is unchanged.
struct MemoSample: SampleContent {
    @State private var counter = 0
    @State private var items = ["Alpha", "Beta", "Gamma"]

    static let id = "memo"
    static let title = "Memoization"
    static let summary = "Skipping a subtree the differ would otherwise walk, compare and send."

    static let code = """
        @State private var counter = 0

        // WHAT THE TOKEN NAMES IS EVERYTHING THE VIEW DEPENDS ON. The count
        // is read inside both blocks; only the second one names it.
        let info = self.debugInfo()

        VStack {
            Button("Count \\(counter)")
                .onClicked { counter += 1 }

            // HELD: the token never moves, so this is built once and the
            // count it shows stays at whatever it was then.
            VStack {
                Label("\\(counter) - \\(info)")
            }
            .memoized(by: 1)

            // FOLLOWS: the count IS the token, so every press builds it.
            VStack {
                Label("\\(counter) - \\(info)")
            }
            .memoized(by: counter)
        }
        """

    var content: Element {
        // What this view is, how many times it has been described, and which
        // state that description was for. Read once, shown in both blocks -
        // so the two counts below say how often each was built.
        let info = debugInfo()

        return VStack {
            Button("Count \(counter)")
                .padding(20, 10)
                .horizontalOptions(.center)
                .onClicked { counter += 1 }

            // TWO BLOCKS READING THE SAME STATE, told apart by one word.
            Label("Both blocks below show the same count and the same build "
                + "line. Only the second one names the count in its token.")
                .fontSize(13)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            Block(caption: "HELD - memoized(by: 1)",
                  count: counter, info: info, tint: Palette.accent)
                .memoized(by: 1)

            Block(caption: "FOLLOWS - memoized(by: counter)",
                  count: counter, info: info, tint: Palette.brand)
                .memoized(by: counter)

            // AND A LIST, which is what memoizing is usually for: the rows
            // depend on their item and nothing else, so pressing the button
            // above builds none of them.
            Label("Rows memoized by their item - the button rebuilds none of them")
                .fontSize(13)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            VStack {
                ForEach(items) { item in
                    MemoRow(item: item)
                        .memoized(by: item)
                        .id(item)
                }
            }
            .spacing(6)
        }
        .spacing(12)
    }

    var notes: Element? {
        Label("`.memoized(by:)` names everything the view depends on. While "
            + "the token holds, nothing under it is built, compared or sent - "
            + "state read inside included, which is why the first block's "
            + "count stands still. A view that shows state puts that state in "
            + "the token, as the second one does. Handlers are unaffected: a "
            + "button inside a memoized view reads the state when it fires.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

/// One of the two blocks - the caption, the count it was built with, and how
/// many times it has been described. What it shows is handed to it, so the
/// only thing deciding whether it is built again is the token beside it.
private struct Block: ContentView {
    let caption: String
    let count: Int
    let info: String
    let tint: Color

    var content: Element {
        VStack {
            Label(caption)
                .fontSize(12)
                .fontAttributes(.bold)
                .textColor(tint)

            Label("count \(count)")
                .fontSize(20)
                .fontAttributes(.bold)

            Label(info)
                .fontSize(11)
                .textColor(Palette.subtle)
        }
        .spacing(4)
        .padding(14)
    }
}

/// One row, depending on its item and nothing else.
private struct MemoRow: ContentView {
    let item: String

    var content: Element {
        Label(item)
            .fontSize(15)
            .padding(12, 8)
    }
}
