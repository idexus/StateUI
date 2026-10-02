// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One render in the list.
struct Row: View {
    let pass: InspectedPass
    let scene: ElementID
    let index: Int?
    let chosen: Bool

    var body: some View {
        let mine = pass.entries.filter { $0.scene == scene }
        let built = mine.filter { if case .built = $0.outcome { return true } else { return false } }.count
        let carried = mine.filter { $0.outcome == .carried }.count
        let swift = Look.micros(mine.first { $0.depth == 0 }?.micros ?? pass.describe)
        let host = pass.host.map { host in
            Look.micros(Look.scene(host, at: index) ?? host.apply)
        } ?? "…"

        return VStack {
            Text("#\(pass.number)  \(Look.road(pass.road))  "
                + (pass.causes.isEmpty ? "" : "for " + pass.causes.joined(separator: ", ")))
                .fontSize(12)
                .fontAttributes(.bold)
                .textColor(Look.ink)
                .lineBreak(.tailTruncation)

            Text("Swift \(swift) · host \(host) · \(built) built · \(carried) carried")
                .fontSize(11)
                .textColor(Look.subtle)
                .lineBreak(.tailTruncation)
        }
        .spacing(1)
        .padding(horizontal: 8, vertical: 4)
        .background(chosen ? Look.chosen : .transparent)
    }
}
