// A row of headings, one of them chosen.

import StateUI

/// Tabs inside a page.
///
/// The gallery's own, deliberately: MAUI's tabs are a `TabbedPage`, and each of
/// them shows a whole PAGE. This is a strip inside one page, and it switches
/// nothing by itself - it reports which title was tapped and the caller decides
/// what that means.
struct Tabs: ContentView {
    /// What this strip calls itself, for the one test that has to know the
    /// page's chrome from the sample inside it.
    static let strip = "sample-tabs"

    /// What each tab is called, left to right. Also how many there are.
    private let titles: [String]

    /// Which one is chosen, as an index into `titles`.
    private var choice: Binding<Int>?

    /// - Parameter titles: What each tab is called, left to right.
    init(_ titles: [String]) {
        self.titles = titles
    }

    /// Which tab is chosen, as an index into the titles. Two-way: tapping a
    /// tab writes it back to whoever lent it.
    ///
    /// A modifier because every choice in the library is one - `Picker`'s
    /// `selectedIndex`, `CollectionView`'s `selection`, `TabbedPage`'s. A strip
    /// nobody lends a binding to draws its titles with none of them chosen and
    /// reports nothing, which is what those do too.
    func selection(_ binding: Binding<Int>) -> Self {
        var copy = self
        copy.choice = binding
        return copy
    }

    var content: Element {
        // A copy for the handlers to capture, never `self` - see the note in
        // Card.swift.
        let choice = self.choice
        let selected = choice?.wrappedValue ?? -1

        // IN A SCROLLER, because a strip of tabs is as wide as the sample
        // needs and a phone is as wide as it is: a sample with three examples,
        // its notes and its code has five of them, and the last was simply
        // unreachable - there is nothing to drag a row of labels with. A strip
        // that fits is a scroller with nothing to scroll, so a desktop sees no
        // difference.
        return ScrollView {
            HStack {
                // Identified by the OFFSET, deliberately: a tab means its
                // place in the strip, and two tabs may share a caption.
                ForEach(Array(titles.enumerated()), id: \.offset) { tab in
                    let index = tab.offset

                    return VStack {
                        Label(tab.element)
                            .fontSize(13)
                            .fontAttributes(.bold)
                            .characterSpacing(1)
                            .textColor(index == selected ? Palette.accent : Palette.subtle)

                        // The rule is under EVERY tab, quiet on the ones not
                        // chosen. Adding it only to the chosen one would change
                        // the row's height as the choice moves, and the page
                        // below would step up and down with it.
                        //
                        // Quiet, and not `.transparent`: a BoxView whose colour
                        // has no alpha draws BLACK on Android - measured, on an
                        // emulator, with the unchosen tab underlined in the one
                        // colour nothing else on the page uses.
                        BoxView()
                            .heightRequest(2)
                            .color(index == selected ? Palette.accent : Palette.outline)
                    }
                    .spacing(6)
                    .onTapped { choice?.wrappedValue = index }
                }
            }
            .spacing(20)
        }
        .orientation(.horizontal)
        // The bar under a row of tabs would sit on the rule, and the row is
        // short enough that a reader can see there is more.
        .horizontalScrollBarVisibility(.never)
        // NAMED, so the guard that keeps a gesture sample out of a scroller can
        // tell the page's own chrome from the sample: the taps in here are
        // tabs, which a scroller passes through, and the rule is about the
        // EXAMPLE - see CatalogTests.
        .id(Self.strip)
    }
}
