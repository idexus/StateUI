// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `ContentContract` on a host: the view a title bar holds in its middle stands there, and takes the user's hand.
@_spi(Host) public enum ContentTests: ConformanceFamily {
    public static let name = "Content"

    public static var cases: [ConformanceCase] {
        [TitleBarSlots.stands(ContentContract.self) { bar, button in bar.content { button } }]
    }
}

/// The cases of a title bar's slots: the view each holds stands in the bar, and a press on it is heard.
enum TitleBarSlots {
    /// The view the slot of `Slot` holds - put there by `fill` - stands in the window's title bar and hears a press.
    static func stands<Slot: ElementContract>(
        _ slot: Slot.Type, _ fill: @escaping @Sendable (TitleBar, Button) -> TitleBar
    ) -> ConformanceCase {
        ConformanceCase("theViewItHoldsStandsInTheTitleBar", covers: [Covered(Slot.self), Covered(ButtonContract.clicked)]) { s in
            let heard = Received<String>()
            s.start {
                SessionPage { _, window in
                    window.titleBar = fill(TitleBar("Notes"), Button("Slot").onClicked { heard.values.append("pressed") }.id("slot"))
                }
            }
            let button = try s.element("slot")
            try s.settle { try s.held(VisualElementContract.isVisible, on: button) == true }

            try s.perform(.activate, on: button)
            s.settle { heard.values == ["pressed"] }
            s.expect(heard.values, ["pressed"])
        }
    }
}
