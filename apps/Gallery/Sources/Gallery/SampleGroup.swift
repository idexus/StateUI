// One row of the menu, and everything under it.

import StateUI

/// A category of samples - one menu row, one page listing what is in it.
///
/// The names are the ones a reader already looks under - "Controls" for the
/// things you tap, "Lists & cards" for the things that show many items - and
/// where two groups could both claim a sample, the summary says which has it
/// ("text fields are under Text & typing"), so nobody has to guess twice.
///
/// THE FIRST GROUP IS THE CARD IN FRONT on the home page, which is what a
/// reader taps before they have read anything, so it holds what this library
/// IS: one declaration, the reader rule, the two layers and what each costs.
/// Chrome - styles, the window, its title bar and its lifecycle - is further
/// down under names that say so.
struct SampleGroup {
    /// What the menu row and the home card push - the value inside
    /// `Route.group("layout")`, and the key a test names a group by.
    let route: String

    /// The menu row's caption and the page's heading.
    let title: String

    /// One line about what the group is for.
    let summary: String

    /// A file in Resources/Images, by the name MAUI gives it once built.
    let icon: ImageSource

    /// The group's CARD - the picture the home page's gallery turns through,
    /// one per group and each in its own colour. A file in Resources/Images,
    /// by the name MAUI gives it once built.
    let card: ImageSource

    let samples: [Sample]

    /// The samples a device of `idiom` lists, through `Sample.isShown(on:)`.
    /// What every page and count reads, each passing the idiom it resolved
    /// with `@Environment var device: DeviceInfo`; `samples` is the whole
    /// set, which is what the pushed pages and the tests read.
    func shown(on idiom: DeviceIdiom) -> [Sample] {
        samples.filter { $0.isShown(on: idiom) }
    }
}

/// A group IS its route: the catalog makes every group once, so two groups with
/// one route are the same group - which is what lets the page showing one be
/// carried when the window builds for a move further up the stack, rather than
/// built again with every card on it.
extension SampleGroup: Equatable {
    static func == (a: SampleGroup, b: SampleGroup) -> Bool { a.route == b.route }
}
