// One row of the menu, and everything under it.

import StateUI

/// A category of samples - one menu row, one page listing what is in it.
///
/// The names follow the WinUI 3 Gallery's, because they are the ones people
/// already look under: "Basic input" holds the things you type and tap,
/// "Collections" the things that show many items. What lives in each is MAUI's,
/// though: a `Picker` is basic input here because MAUI treats it as one.
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

    let samples: [Sample]

    /// The samples a device of `idiom` lists, through `Sample.isShown(on:)`.
    /// What every page and count reads, each passing the idiom it resolved
    /// with `@Environment var device: DeviceInfo`; `samples` is the whole
    /// set, which is what the pushed pages and the tests read.
    func shown(on idiom: DeviceIdiom) -> [Sample] {
        samples.filter { $0.isShown(on: idiom) }
    }
}
