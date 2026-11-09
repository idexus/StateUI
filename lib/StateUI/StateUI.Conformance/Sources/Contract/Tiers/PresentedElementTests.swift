// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `PresentedElementContract` on a host, on each element wearing the tier, in the place it stands.
@_spi(Host) public enum PresentedElementTests: ConformanceFamily {
    public static let name = "PresentedElement"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("Sheet.theUsersWayBackClosesTheTopSheetOntoItsState", proves: [
                Covered(PresentedElementContract.isPresented, on: SheetContract.self), Covered(PresentedElementContract.isPresentedChanged, on: SheetContract.self),
            ], needs: [Covered(PageContract.appearing)]) { s in
                let states = SheetStates()
                s.start { SheetsPage(states: states) }
                let window = try s.element(ofType: WindowContract.nodeType)
                try s.settle { try s.held(VisualElementContract.isVisible, on: s.element("note")) == true }

                try s.perform(.goBack, on: window)
                s.settle { states.note.wrappedValue == nil }
                s.expect(states.note.wrappedValue, nil, "the value's sheet on top went: nil")
                s.expect(states.shows.wrappedValue, true, "the sheets under it stay")

                try s.perform(.goBack, on: window)
                s.settle { !states.inner.wrappedValue }
                s.expect(states.inner.wrappedValue, false, "the flag's sheet went: false")

                states.log.values = []
                try s.perform(.goBack, on: window)
                s.settle { !states.shows.wrappedValue }
                s.expect(states.shows.wrappedValue, false, "and the last")
                s.settle { states.log.values.contains("beneath appearing") }
                s.expect(states.log.values.contains("beneath appearing"), true, "the page beneath shows again")
            },
            ConformanceCase("Sheet.theApplicationClosesASheetByItsState", proves: [
                Covered(PresentedElementContract.isPresented, on: SheetContract.self),
            ], needs: [Covered(TextContract.self)]) { s in
                let states = SheetStates()
                s.start { SheetsPage(states: states) }
                try s.settle { try s.isShown("note") }

                states.note.wrappedValue = nil
                s.settle { (try? s.element("note")) == nil }
                s.expect((try? s.element("note")) == nil, true, "the value's sheet gone with its value")

                states.shows.wrappedValue = false
                s.settle { (try? s.element("outer")) == nil }
                s.expect((try? s.element("outer")) == nil, true, "the flag's sheet gone with its flag")
            },
            ConformanceCase("Sheet.aViewLeavingTakesItsSheetAway", proves: [
                Covered(PresentedElementContract.isPresented, on: SheetContract.self),
            ], needs: [Covered(TextContract.self)]) { s in
                let states = SheetStates()
                s.start { SheetsPage(states: states) }
                try s.settle { try s.isShown("note") }

                states.presents.wrappedValue = false
                s.settle { (try? s.element("note")) == nil && (try? s.element("outer")) == nil }
                s.expect((try? s.element("outer")) == nil, true, "the sheets gone with the views presenting them")
                s.expect(states.shows.wrappedValue, false, "the flag written false")
                s.expect(states.note.wrappedValue, nil, "the value written nil")
            },
            ConformanceCase("Sheet.aSheetClosingTakesTheSheetInIt", proves: [
                Covered(PresentedElementContract.isPresented, on: SheetContract.self),
            ], needs: [Covered(TextContract.self)]) { s in
                let states = SheetStates()
                states.note.wrappedValue = nil
                s.start { SheetsPage(states: states) }
                try s.settle { try s.isShown("inner") }

                states.shows.wrappedValue = false
                s.settle { (try? s.element("inner")) == nil }
                s.expect((try? s.element("inner")) == nil, true, "the sheet in it gone with it")
                s.expect(states.inner.wrappedValue, false, "its flag written false")
            },
            ConformanceCase("Sheet.anotherValuePresentsAnotherPageInItsPlace", proves: [
                Covered(PresentedElementContract.isPresented, on: SheetContract.self),
            ], needs: [Covered(TextContract.self)]) { s in
                let states = SheetStates()
                (states.shows.wrappedValue, states.inner.wrappedValue) = (false, false)
                s.start { SheetsPage(states: states) }
                try s.settle { try s.isShown("note") }

                states.note.wrappedValue = "Archive"
                try s.settle {
                    try s.held(TextElementContract.text, on: s.element("note")) == "Archive" && s.isShown("note")
                }
                s.expect(try s.held(TextElementContract.text, on: s.element("note")), "Archive", "the new value's page")
                s.expect(try s.isShown("note"), true, "shown in the first one's place")
            },
            ConformanceCase("Popover.aPopoverShownFromTheStartStandsOnceItsAnchorDoes", proves: [
                Covered(PresentedElementContract.isPresented, on: PopoverContract.self),
            ]) { s in
                let shown = State(wrappedValue: true)
                s.start { FiltersAnchor(shown: shown.projectedValue) }
                let popover = try PopoverTests.popover(of: s.element("anchor"))
                try s.settle { try s.held(PresentedElementContract.isPresented, on: popover) == true }

                s.expect(try s.held(PresentedElementContract.isPresented, on: popover), true, "shown once its anchor stands")
                try s.settle { try s.isShown("inside") }
                s.expect(try s.isShown("inside"), true, "with what it holds")
            },
            ConformanceCase("Popover.theUsersDismissalLandsOnTheState", proves: [
                Covered(PresentedElementContract.isPresented, on: PopoverContract.self),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
                // The state the host carries takes the dismissal the user makes.
                let shown = State(wrappedValue: false)
                s.start { FiltersAnchor(shown: shown.projectedValue) }
                let popover = try PopoverTests.popover(of: s.element("anchor"))
                try s.perform(.activate, on: s.element("anchor"))
                try s.settle { try s.held(PresentedElementContract.isPresented, on: popover) == true }

                try s.perform(.close, on: popover)
                s.settle { !shown.wrappedValue }

                s.expect(shown.wrappedValue, false, "the user's dismissal written")
                try s.settle { try s.held(PresentedElementContract.isPresented, on: popover) == false }
                s.expect(try s.held(PresentedElementContract.isPresented, on: popover), false, "the popover gone")
            },
            ConformanceCase("Popover.aViewLeavingTakesItsPopoverAway", proves: [
                Covered(PresentedElementContract.isPresented, on: PopoverContract.self),
            ], needs: [Covered(TextContract.self)]) { s in
                let (stands, shown) = (State(wrappedValue: true), State(wrappedValue: true))
                s.start { VStack { if stands.wrappedValue { FiltersAnchor(shown: shown.projectedValue) } } }
                try s.settle { try s.isShown("inside") }

                stands.wrappedValue = false
                s.settle { (try? s.element("inside")) == nil && !shown.wrappedValue }
                s.expect((try? s.element("inside")) == nil, true, "the popover gone with the view presenting it")
                s.expect(shown.wrappedValue, false, "its state written false")
            },
            ConformanceCase("Popover.theUsersDismissalWritesNilOntoAValue", proves: [
                Covered(PresentedElementContract.isPresented, on: PopoverContract.self), Covered(PresentedElementContract.isPresentedChanged, on: PopoverContract.self),
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
            ConformanceCase("Popover.aPopoverStaysAsTheViewShowingItFlips", proves: [
                Covered(PresentedElementContract.isPresented, on: PopoverContract.self),
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
}
