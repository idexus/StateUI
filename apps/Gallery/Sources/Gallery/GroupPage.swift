// One category, listing what is in it.

import StateUI

/// The page behind a sidebar entry: every sample in that group, one row each
/// in one rounded group.
///
/// One type for every group rather than one page per category - a group differs
/// by what is in it, and nothing else. Adding a category is a line in the
/// catalog, not a file.
struct GroupPage: View {
    /// The gallery this page is in - its scene.
    @Environment(\.scene) var scene

    let group: SampleGroup

    /// Where the gallery is - a row pushes a sample onto the stack.
    let nav: Navigation

    /// Which kind of device this is - what decides which samples are listed.
    @Environment(\.device) var device

    var body: some View {
        ScrollView {
            VStack {
                // The page's title is its bar's; the line under it says what
                // the group is about.
                Text(group.summary)
                    .textColor(Palette.subtle)

                // Tapping PUSHES the sample's page: one more element on the
                // array the stack is, with the id riding as a value of the
                // route rather than as a string in a dictionary.
                //
                // `shown`, not `samples`: a sample about desktop chrome is not
                // listed on a phone.
                VStack {
                    ForEach(Array(group.shown(on: device.info.formFactor).enumerated()), id: \.element.id) { item in
                        ListRow(item.element.title, summary: item.element.summary) {
                            nav.push(.sample(item.element.id))
                        }
                        .separated(item.offset > 0)
                    }
                }
                .style("RowGroup")
            }
            .spacing(16)
            .padding(24)
        }
        .galleryPage(group.title)
    }
}
