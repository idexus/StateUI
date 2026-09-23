// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An inspector folded to one line: the last render that reached its scene,
/// said the way the list says it, and the button that opens it out again.
struct InspectorStrip: ContentView {
    /// The scene it looks at, by its number.
    let scene: String

    var content: any View {
        let model = InspectorModel.shared

        // Built again as renders land, the way the whole inspector is.
        _ = model.revision

        let element = ElementId.manual(scene)
        let all = Inspection.passes
        let last = all.last { pass in pass.entries.contains { $0.scene == element } }

        return Grid {
            Grid {
                if let last {
                    Row(pass: last, scene: element, index: Scenes.shared.index(of: scene), chosen: false)
                } else {
                    Label(InspectorView.waiting(all.count))
                        .fontSize(12)
                        .textColor(Look.subtle)
                        .lineBreak(.tailTruncation)
                        .margin(8, 4)
                }
            }
            .verticalAlignment(.center)
            .gridColumn(0)

            HStack {
                Look.icon(Look.expanding, "Expand") { model.expand(scene) }
                Look.icon(Look.closing, "Close") {
                    if let record = Scenes.shared.record(id: scene) {
                        Inspector.hide(in: record)
                    }
                }
            }
            .verticalAlignment(.center)
            .gridColumn(1)
        }
        .columns(.fill, .auto)
        .padding(2, 4)
    }
}
