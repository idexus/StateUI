// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `StackBaseContract` on a host: a stack keeps its children the spacing apart the tree says, and the spacing the
/// tree changes it to - each case made for every stack.
@_spi(Host) public enum StackBaseTests: ConformanceFamily {
    public static let name = "StackBase"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(StackBaseContract.self).flatMap { element in
            [spaced(element), Aspects.holds(StackBaseContract.spacing, on: element, 4, then: 12)]
        }
    }

    /// A stack's children stand the spacing apart.
    static func spaced(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).keepsItsChildrenItsSpacingApart", covers: [
            Covered(StackBaseContract.spacing, on: element), Covered(ButtonContract.clicked),
        ]) { s in
            let wide = State(wrappedValue: false)
            let second = Received<[Double]>()
            s.start {
                VStack {
                    Stacked.stack(element, spacing: wide.wrappedValue ? 20 : 10) {
                        [
                            ColorBox(.red).width(20).height(20),
                            ColorBox(.blue).width(20).height(20).onEvent(ViewContract.frameChanged) { second.values.append($0) },
                        ]
                    }
                    Button("Wider").onClicked { wide.wrappedValue = true }.id("change")
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            let along = element == "HStack" ? 0 : 1
            s.settle { second.values.last.map(FrameReport.place)?[along] == 30 }
            s.expect(second.values.last.map(FrameReport.place)?[along], 30, "the first's 20 and the spacing's 10 on")

            try s.perform(.activate, on: s.element("change"))
            s.settle { second.values.last.map(FrameReport.place)?[along] == 40 }
            s.expect(second.values.last.map(FrameReport.place)?[along], 40, "the spacing the tree changed it to")
        }
    }
}

/// A stack of each kind holding views, as a stack's cases need it.
enum Stacked {
    /// A stack of `element`'s kind, its children `spacing` apart.
    static func stack(_ element: String, spacing: Double, _ children: () -> [any View]) -> any View {
        let held: [Element] = children().map { $0 }
        if element == "HStack" { return HStack { held }.spacing(spacing) }
        return VStack { held }.spacing(spacing)
    }
}
