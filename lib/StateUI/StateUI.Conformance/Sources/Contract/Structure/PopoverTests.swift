// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `PopoverContract` on a host: the popover a state shows stands by its anchor with what it holds, and goes as the
/// state says; it closes every way it can, each written onto its state - the user's dismissal, the application's
/// write, the view presenting it leaving - by a flag and by a value alike, and stays as that view's branch flips.
@_spi(Host) public enum PopoverTests: ConformanceFamily {
    public static let name = "Popover"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aPopoverTheStateShowsStandsWithWhatItHolds", proves: [
                Covered(PopoverContract.self),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
                let shown = State(wrappedValue: false)
                s.start { FiltersAnchor(shown: shown.projectedValue) }
                let popover = try Self.popover(of: s.element("anchor"))
                s.expect(try s.held(PresentedElementContract.isPresented, on: popover), false)
                s.expect(try s.isShown("inside"), false, "what it holds shows nowhere yet")

                try s.perform(.activate, on: s.element("anchor"))
                try s.settle { try s.held(PresentedElementContract.isPresented, on: popover) == true }

                s.expect(try s.held(PresentedElementContract.isPresented, on: popover), true, "the popover the state showed")
                try s.settle { try s.isShown("inside") }
                s.expect(try s.isShown("inside"), true, "with what it holds")
                try s.perform(.activate, on: s.element("done"))
                try s.settle { try s.held(PresentedElementContract.isPresented, on: popover) == false }
                s.expect(try s.held(PresentedElementContract.isPresented, on: popover), false, "and gone as the state says")
            },
        ]
    }

    /// The popover `anchor` declares.
    @MainActor
    static func popover(of anchor: MountedElement) throws -> MountedElement {
        guard let popover = anchor.children.first(where: { $0.type == .popover }) else {
            throw Session.Missing(id: "the popover of \(anchor.id)")
        }
        return popover
    }
}

/// A button showing its popover of filters, which a button inside closes.
struct FiltersAnchor: View {
    let shown: Binding<Bool>

    var body: some View {
        VStack {
            Button("Filters").onClicked { shown.wrappedValue = true }
                .popover(isPresented: shown) {
                    VStack {
                        Text("Unread only").id("inside")
                        Button("Done").onClicked { shown.wrappedValue = false }.id("done")
                    }
                    .padding(12)
                }
                .id("anchor")
        }
    }
}

/// A button showing a popover of the topic its state holds.
struct TopicAnchor: View {
    let topic: Binding<String?>

    var body: some View {
        VStack {
            Button("Why?").onClicked { topic.wrappedValue = "Sync" }
                .popover(item: topic) { topic in
                    Text(topic).padding(12).id(topic)
                }
        }
    }
}

/// A group of one button or another, showing a popover by the one it shows while `shown` says so.
struct FlippingAnchor: View {
    let wide: State<Bool>
    let shown: State<Bool>

    var body: some View {
        let wide = self.wide.wrappedValue
        return VStack {
            Group {
                if wide {
                    Button("Wide")
                } else {
                    Button("Narrow")
                }
            }
            .popover(isPresented: shown.projectedValue) {
                Text("Inside").padding(12).id("inside")
            }
        }
    }
}
