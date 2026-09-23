// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An inspector itself: what it can do, its scene's renders, and the one
/// chosen.
struct InspectorView: ContentView {
    /// The scene it looks at, by its number.
    let scene: String

    /// Where it shows.
    let place: Inspector.Place

    /// Whether there is room for the renders and the chosen one side by side.
    let wide: Bool

    var content: any View {
        let model = InspectorModel.shared

        // Reading the revision rebuilds this view when a pass lands.
        _ = model.revision

        // Shown means recording, however it came to be shown - the ⓘ, or a
        // scene opening its inspector's window by itself.
        model.record()

        let element = ElementId.manual(scene)
        let index = Scenes.shared.index(of: scene)
        let all = Array(Inspection.passes.reversed())
        let passes = InspectorView.history(of: element, in: all)
        let chosen = model.selected.flatMap { number in passes.first { $0.number == number } }

        // Each part in a cell of its own, which is what a part answered as a
        // plain view is placed by.
        return Grid {
            Grid { head(model) }
                .gridRow(0)

            Label(summary(passes, all: all.count, at: index))
                .fontSize(11)
                .textColor(Look.subtle)
                .lineBreak(.tailTruncation)
                .gridRow(1)

            if wide {
                Grid {
                    Grid { list(passes, scene: element, at: index) }
                        .gridColumn(0)

                    Grid { detail(chosen, scene: element, at: index) }
                        .gridColumn(1)
                }
                .columns(.proportional(1), .proportional(1.5))
                .columnSpacing(10)
                .gridRow(2)
            } else if let chosen {
                Grid { detail(chosen, scene: element, at: index) }
                    .gridRow(2)
            } else {
                Grid { list(passes, scene: element, at: index) }
                    .gridRow(2)
            }
        }
        .rows(.auto, .auto, .fill)
        .rowSpacing(6)
        .padding(10, 8)
    }

    /// A scene's history: the renders that reached it, in the order given.
    ///
    /// - Parameters:
    ///   - scene: the scene's element.
    ///   - passes: the renders.
    static func history(of scene: ElementId, in passes: [InspectedPass]) -> [InspectedPass] {
        passes.filter { pass in pass.entries.contains { $0.scene == scene } }
    }

    /// What an inspector says while no render has reached its scene.
    ///
    /// - Parameter all: how many renders there are, in every scene.
    static func waiting(_ all: Int) -> String {
        if !Inspection.recording {
            return "Paused - nothing is being recorded."
        }

        return all == 0
            ? "Waiting for a render. Use the application; every render lands here."
            : "Nothing has reached this scene yet - \(all) renders elsewhere."
    }

    /// What it can do - hold the record, forget it, move, go.
    ///
    /// A horizontally scrolling action row that remains reachable in a narrow
    /// inspector.
    private func head(_ model: InspectorModel) -> Element {
        let record = Scenes.shared.record(id: scene)
        let windowed = record.map(Inspector.windowed) ?? false
        let close: () -> Void = {
            if let record {
                Inspector.hide(in: record)
            }
        }

        let actions = ScrollView {
            HStack {
                Label("Inspector")
                    .fontSize(15)
                    .fontAttributes(.bold)
                    .textColor(Look.ink)
                    .margin(0, 0, 10, 4)

                Look.action(model.paused ? "Record" : "Pause") { model.pause() }
                Look.action("Clear") { model.clear() }

                if place == .window {
                    Look.action("Dock in the window") {
                        if let record {
                            Inspector.show(in: record, Inspector.offersSide ? .side : .bottom)
                        }
                    }
                } else {
                    if Inspector.offersSide {
                        Look.action(place == .side ? "Dock at the bottom" : "Dock at the side") {
                            if let record {
                                Inspector.show(in: record, place == .side ? .bottom : .side)
                            }
                        }
                    }

                    if windowed {
                        Look.action("Open in a window") {
                            if let record {
                                Inspector.show(in: record, .window)
                            }
                        }
                    }
                }

                if place != .bottom {
                    Look.action("Close", close)
                }
            }
            .spacing(6)
        }
        .orientation(.horizontal)
        .horizontalScrollBarVisibility(.never)

        guard place == .bottom else { return actions }

        // ALONG THE BOTTOM THE LAST TWO ARE PICTURES AT THE END OF THE ROW -
        // the same two the folded line ends with, this one folding it where
        // that one opens it out.
        return Grid {
            actions.gridColumn(0)

            HStack {
                Look.icon(Look.folding, "Collapse") { model.fold(scene) }
                Look.icon(Look.closing, "Close", close)
            }
            .verticalAlignment(.start)
            .gridColumn(1)
        }
        .columns(.fill, .auto)
    }

    /// One line about the scene's renders.
    private func summary(_ passes: [InspectedPass], all: Int, at index: Int?) -> String {
        guard let last = passes.first else { return InspectorView.waiting(all) }

        let paused = Inspection.recording ? "" : "paused · "
        let renders = passes.count == 1 ? "1 render" : "\(passes.count) renders"
        let others = all > passes.count ? " (\(all) in all)" : ""
        let swift = Look.micros(last.describe + last.encode)
        let host = last.host.map { Look.micros($0.read + $0.apply) } ?? "…"

        return "\(paused)\(renders) here\(others) · the last: Swift \(swift) + host \(host)"
    }

    /// The scene's renders, newest first.
    private func list(_ passes: [InspectedPass], scene: ElementId, at index: Int?) -> Element {
        let model = InspectorModel.shared

        return ScrollView {
            VStack {
                ForEach(passes, id: \.number) { pass in
                    Row(
                        pass: pass,
                        scene: scene,
                        index: index,
                        chosen: model.selected == pass.number)
                    .onTapped { model.selected = pass.number }
                }
            }
        }
    }

    /// The render chosen: its numbers, then its tree in this scene.
    private func detail(_ chosen: InspectedPass?, scene: ElementId, at index: Int?) -> Element {
        guard let pass = chosen else {
            return Label("Choose a render to see what it built.")
                .fontSize(12)
                .textColor(Look.subtle)
                .verticalAlignment(.start)
        }

        let entries = pass.entries.filter { $0.scene == scene }
        let whole = entries.first { $0.depth == 0 }

        return Grid {
            VStack {
                HStack {
                    if !wide {
                        Look.action("‹ Renders") { InspectorModel.shared.selected = nil }
                    }

                    Label("Render #\(pass.number) · \(Look.road(pass.road))")
                        .fontSize(13)
                        .fontAttributes(.bold)
                        .textColor(Look.ink)
                        .verticalAlignment(.center)
                }
                .spacing(8)

                Look.line(pass.causes.isEmpty
                    ? "caused by nothing named"
                    : "for " + pass.causes.joined(separator: ", "))
                Look.line(
                    "at \(Look.seconds(pass.at)) · generation \(pass.generation) · "
                        + "\(pass.bytes) bytes")
                Look.line(
                    "Swift  describe \(Look.micros(pass.describe)) · encode \(Look.micros(pass.encode))"
                        + (pass.own > 0 ? " · the inspector's own \(Look.micros(pass.own)), left out" : ""))
                Look.line(host(pass.host))
                Look.line(
                    "this scene  Swift \(whole.map { Look.micros($0.micros) } ?? "nothing built")"
                        + (Look.scene(pass.host, at: index).map { " · host \(Look.micros($0))" } ?? ""))

                if pass.truncated {
                    Look.line("only the first \(Inspection.most) views are listed")
                }
            }
            .spacing(2)
            .gridRow(0)

            ScrollView {
                VStack {
                    ForEach(Array(entries.enumerated()), id: \.offset) { item in
                        Branch(entry: item.element)
                    }
                }
            }
            .gridRow(1)
        }
        .rows(.auto, .fill)
        .rowSpacing(8)
    }

    /// The host's half, in one line.
    private func host(_ host: InspectedHost?) -> String {
        guard let host else { return "Host  not reported yet" }

        return "Host  read \(Look.micros(host.read)) · apply \(Look.micros(host.apply)) · "
            + "\(host.nodes) nodes · \(host.made) made · \(host.kept) kept · \(host.adopted) adopted"
    }
}

/// One composed view of the chosen render's tree.
private struct Branch: ContentView {
    let entry: InspectedEntry

    var content: any View {
        let (mark, said, colour): (String, String, Color) = {
            switch entry.outcome {
            case let .built(reason):
                return ("●", "\(reason) · \(Look.micros(entry.micros)) (\(Look.micros(entry.own)) own)",
                    Look.built)
            case .carried:
                return ("○", "carried", Look.carried)
            case .walked:
                return ("·", "walked · \(Look.micros(entry.micros))", Look.subtle)
            }
        }()

        return Label("\(mark) \(entry.view) — \(said)")
            .fontSize(12)
            .textColor(colour)
            .lineBreak(.tailTruncation)
            .padding(Double(entry.depth) * 12 + 6, 2)
            .horizontalAlignment(.start)
    }
}
