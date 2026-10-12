// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `FocusElementContract` on a host: the keyboard put on an element and taken off it, heard both ways; each case
/// made for every element wearing the tier.
@_spi(Host) public enum FocusElementTests: ConformanceFamily {
    public static let name = "FocusElement"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(FocusElementContract.self).map(focused)
    }

    /// The keyboard put on the element is heard coming, and heard going as it is taken off. One that refuses it on a
    /// host says so and hears nothing.
    @MainActor
    static func focused(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).theKeyboardComingAndGoingIsHeard", proves: [
            Covered(FocusElementContract.focus, on: element), Covered(FocusElementContract.unfocus, on: element),
            Covered(FocusElementContract.isFocusedChanged, on: element),
        ], needs: [Covered(ButtonContract.clicked)]) { s in
            let aim = FocusAim()
            let heard = Received<Bool>()
            let took = Received<Bool>()
            s.start {
                VStack {
                    Opened.aimed(Specimens.view(element, [
                        Hear(FocusElementContract.isFocusedChanged) { heard.values.append($0) },
                    ]), by: aim)
                    Button("Focus").onClicked(gate: .ignoreWhileRunning) { took.values.append(try await aim.focus()) }.id("focus")
                    Button("Unfocus").onClicked(gate: .ignoreWhileRunning) { try await aim.unfocus() }.id("unfocus")
                }
            }
            let view = try s.element("specimen")

            try s.perform(.activate, on: s.element("focus"))
            s.settle { !took.values.isEmpty && (took.values == [false] || heard.values == [true]) }
            guard took.values == [true] else {
                s.expect(heard.values, [], "a view that refused the keyboard hears nothing")
                s.expect(try s.focused(view), false)
                throw s.absent("\(element) takes no keyboard focus here: it refuses it, and nothing is heard")
            }
            s.expect(heard.values, [true], "the keyboard coming heard")
            s.expect(try s.focused(view), true)

            try s.perform(.activate, on: s.element("unfocus"))
            s.settle { heard.values == [true, false] }
            s.expect(heard.values, [true, false], "and its going")
            s.expect(try s.focused(view), false)
        }
    }
}
