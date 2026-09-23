// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One render in the list.
struct Row: ContentView {
    let pass: InspectedPass
    let scene: ElementId
    let index: Int?
    let chosen: Bool

    var content: any View {
        let mine = pass.entries.filter { $0.scene == scene }
        let built = mine.filter { if case .built = $0.outcome { return true } else { return false } }.count
        let carried = mine.filter { $0.outcome == .carried }.count
        let swift = Look.micros(mine.first { $0.depth == 0 }?.micros ?? pass.describe + pass.encode)
        let host = pass.host.map { host in
            Look.micros(Look.scene(host, at: index) ?? host.read + host.apply)
        } ?? "…"

        return VStack {
            Label("#\(pass.number)  \(Look.road(pass.road))  "
                + (pass.causes.isEmpty ? "" : "for " + pass.causes.joined(separator: ", ")))
                .fontSize(12)
                .fontAttributes(.bold)
                .textColor(Look.ink)
                .lineBreak(.tailTruncation)

            Label("Swift \(swift) · host \(host) · \(built) built · \(carried) carried")
                .fontSize(11)
                .textColor(Look.subtle)
                .lineBreak(.tailTruncation)
        }
        .spacing(1)
        .padding(8, 4)
        .background(chosen ? Look.chosen : .transparent)
    }
}
