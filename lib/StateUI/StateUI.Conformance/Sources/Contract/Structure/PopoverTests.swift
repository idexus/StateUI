// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `PopoverContract` on a host: the popover a state shows stands by its anchor with what it holds, and goes as the
/// state says; the user's dismissal lands on the state, and nobody hears the application's own.
@_spi(Host) public enum PopoverTests: ConformanceFamily {
    public static let name = "Popover"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aPopoverTheStateShowsStandsWithWhatItHolds", proves: [
                Covered(PopoverContract.self), Covered(PopoverContract.isShown),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let shown = State(wrappedValue: false)
                s.start { FiltersAnchor(shown: shown.projectedValue) }
                let popover = try Self.popover(of: s.element("anchor"))
                s.expect(try s.held(PopoverContract.isShown, on: popover), false)
                s.expect(try s.isShown("inside"), false, "what it holds shows nowhere yet")

                try s.perform(.activate, on: s.element("anchor"))
                try s.settle { try s.held(PopoverContract.isShown, on: popover) == true }

                s.expect(try s.held(PopoverContract.isShown, on: popover), true, "the popover the state showed")
                try s.settle { try s.isShown("inside") }
                s.expect(try s.isShown("inside"), true, "with what it holds")
                try s.perform(.activate, on: s.element("done"))
                try s.settle { try s.held(PopoverContract.isShown, on: popover) == false }
                s.expect(try s.held(PopoverContract.isShown, on: popover), false, "and gone as the state says")
            },
            ConformanceCase("aPopoverShownFromTheStartStandsOnceItsAnchorDoes", proves: [
                Covered(PopoverContract.isShown),
            ]) { s in
                let shown = State(wrappedValue: true)
                s.start { FiltersAnchor(shown: shown.projectedValue) }
                let popover = try Self.popover(of: s.element("anchor"))
                try s.settle { try s.held(PopoverContract.isShown, on: popover) == true }

                s.expect(try s.held(PopoverContract.isShown, on: popover), true, "shown once its anchor stands")
                try s.settle { try s.isShown("inside") }
                s.expect(try s.isShown("inside"), true, "with what it holds")
            },
            ConformanceCase("theUsersDismissalLandsOnTheState", proves: [
                Covered(PopoverContract.isShown), Covered(PopoverContract.isShownChanged),
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
                try s.settle { try s.held(PopoverContract.isShown, on: popover) == true }
                written.values = []

                try s.perform(.close, on: popover)
                s.settle { !shown.wrappedValue }

                s.expect(written.values, [false], "the user's dismissal written once")
                try s.settle { try s.held(PopoverContract.isShown, on: popover) == false }
                s.expect(try s.held(PopoverContract.isShown, on: popover), false, "the popover gone")
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
                .popover(isShown: shown) {
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
