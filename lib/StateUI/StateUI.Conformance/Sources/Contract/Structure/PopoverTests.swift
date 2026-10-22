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
                Covered(PopoverContract.self), Covered(PopoverContract.isPresented),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let shown = State(wrappedValue: false)
                s.start { FiltersAnchor(shown: shown.projectedValue) }
                let popover = try Self.popover(of: s.element("anchor"))
                s.expect(try s.held(PopoverContract.isPresented, on: popover), false)
                s.expect(try s.isShown("inside"), false, "what it holds shows nowhere yet")

                try s.perform(.activate, on: s.element("anchor"))
                try s.settle { try s.held(PopoverContract.isPresented, on: popover) == true }

                s.expect(try s.held(PopoverContract.isPresented, on: popover), true, "the popover the state showed")
                try s.settle { try s.isShown("inside") }
                s.expect(try s.isShown("inside"), true, "with what it holds")
                try s.perform(.activate, on: s.element("done"))
                try s.settle { try s.held(PopoverContract.isPresented, on: popover) == false }
                s.expect(try s.held(PopoverContract.isPresented, on: popover), false, "and gone as the state says")
            },
            ConformanceCase("aPopoverShownFromTheStartStandsOnceItsAnchorDoes", proves: [
                Covered(PopoverContract.isPresented),
            ]) { s in
                let shown = State(wrappedValue: true)
                s.start { FiltersAnchor(shown: shown.projectedValue) }
                let popover = try Self.popover(of: s.element("anchor"))
                try s.settle { try s.held(PopoverContract.isPresented, on: popover) == true }

                s.expect(try s.held(PopoverContract.isPresented, on: popover), true, "shown once its anchor stands")
                try s.settle { try s.isShown("inside") }
                s.expect(try s.isShown("inside"), true, "with what it holds")
            },
            ConformanceCase("theUsersDismissalLandsOnTheState", proves: [
                Covered(PopoverContract.isPresented), Covered(PopoverContract.isPresentedChanged),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                // A binding the host cannot carry hears the dismissal as the event, the written value with it.
                let shown = State(wrappedValue: false)
                let written = Received<Bool>()
                let bound = Binding(get: { shown.wrappedValue }, set: {
                    written.values.append($0)
                    shown.wrappedValue = $0
                })
                s.start { FiltersAnchor(shown: bound) }
                let popover = try Self.popover(of: s.element("anchor"))
                try s.perform(.activate, on: s.element("anchor"))
                try s.settle { try s.held(PopoverContract.isPresented, on: popover) == true }
                written.values = []

                try s.perform(.close, on: popover)
                s.settle { !shown.wrappedValue }

                s.expect(written.values, [false], "the user's dismissal written once")
                try s.settle { try s.held(PopoverContract.isPresented, on: popover) == false }
                s.expect(try s.held(PopoverContract.isPresented, on: popover), false, "the popover gone")
            },
            ConformanceCase("aViewLeavingTakesItsPopoverAway", proves: [
                Covered(PopoverContract.isPresented),
            ], needs: [Covered(TextContract.self)]) { s in
                let (stands, shown) = (State(wrappedValue: true), State(wrappedValue: true))
                s.start { VStack { if stands.wrappedValue { FiltersAnchor(shown: shown.projectedValue) } } }
                try s.settle { try s.isShown("inside") }

                stands.wrappedValue = false
                s.settle { (try? s.element("inside")) == nil && !shown.wrappedValue }
                s.expect((try? s.element("inside")) == nil, true, "the popover gone with the view presenting it")
                s.expect(shown.wrappedValue, false, "its state written false")
            },
            ConformanceCase("theUsersDismissalWritesNilOntoAValue", proves: [
                Covered(PopoverContract.isPresented), Covered(PopoverContract.isPresentedChanged),
            ], needs: [Covered(TextContract.self)]) { s in
                let topic = State<String?>(wrappedValue: "Sync")
                s.start { TopicAnchor(topic: topic.projectedValue) }
                try s.settle { try s.isShown("Sync") }

                topic.wrappedValue = "Backup"
                try s.settle { try s.isShown("Backup") }
                s.expect((try? s.element("Sync")) == nil, true, "another value shows another view in its place")

                try s.perform(.close, on: s.element(ofType: PopoverContract.nodeType))
                s.settle { topic.wrappedValue == nil }
                s.expect(topic.wrappedValue, nil, "the user's dismissal written nil")
            },
            ConformanceCase("aPopoverStaysAsTheViewShowingItFlips", proves: [
                Covered(PopoverContract.isPresented),
            ], needs: [Covered(TextContract.self), Covered(AnchorContract.self)]) { s in
                let (wide, shown) = (State(wrappedValue: false), State(wrappedValue: true))
                s.start { FlippingAnchor(wide: wide, shown: shown) }
                try s.settle { try s.isShown("inside") }

                wide.wrappedValue = true
                s.settle { s.elements(ofType: ButtonContract.nodeType).contains { $0.value(.text)?.string == "Wide" } }
                try s.settle { try s.isShown("inside") }
                s.expect(try s.isShown("inside"), true, "the popover shows on")
                s.expect(shown.wrappedValue, true, "its state left as it was")
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
