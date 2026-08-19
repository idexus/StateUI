// One category, listing what is in it.

import StateUI

/// The page behind a flyout entry: every sample in that group, one card each.
///
/// One type for every group rather than one page per category - a group differs
/// by what is in it, and nothing else. Adding a category is a line in the
/// catalog, not a file.
struct GroupPage: GalleryPage {
    let group: SampleGroup

    /// Where the gallery is - a card pushes a sample onto the stack.
    let nav: Navigation

    /// Which kind of device this is - what decides which samples are listed.
    @Environment var device: DeviceInfo

    var title: String? { group.title }

    var content: Element {
        ScrollView {
            VStack {
                Label(group.title)
                    .fontSize(28)
                    .fontAttributes(.bold)

                Label(group.summary)
                    .fontSize(14)
                    .textColor(Palette.subtle)

                // Tapping PUSHES the sample's page: one more element on the
                // array the stack is, with the id riding as a value of the
                // route rather than as a string in a dictionary.
                // `shown`, not `samples`: a sample about desktop chrome is not
                // listed on a phone.
                ForEach(group.shown(on: device.idiom), id: \.id) { sample in
                    Card(sample.title, summary: sample.summary) {
                        nav.push(.sample(sample.id))
                    }
                }
            }
            .spacing(14)
            .padding(24)
        }
    }
}
