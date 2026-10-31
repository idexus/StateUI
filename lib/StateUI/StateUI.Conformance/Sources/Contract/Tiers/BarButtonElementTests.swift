// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `BarButtonElementContract` on a host drawing its bar itself: a button on the bar - an action, a setting -
/// follows a press on it.
@_spi(Host) public enum BarButtonElementTests: ConformanceFamily {
    public static let name = "BarButtonElement"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(BarButtonElementContract.self).map(pressed)
    }

    /// A press on a button shows its pressed values while it holds, and letting go gives its own back.
    @MainActor
    static func pressed(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).followsAPressOnIt", proves: [
            Covered(BarButtonElementContract.pressed, on: element), Covered(BarButtonElementContract.released, on: element),
        ], needs: [Covered(BarItemElementContract.background, on: element)]) { s in
            s.start { BarItemStates.page(element, .pressed) }
            let button = try s.element("specimen")
            let background = { try s.held(BarItemElementContract.background, on: button) }
            try s.settle { try background() == .color(.steelBlue) }

            try s.perform(.pressDown(at: Point(8, 8)), on: button)
            try s.settle { try background() == .color(.firebrick) }
            s.expect(try background(), .color(.firebrick), "its pressed background while the press holds")

            try s.perform(.lift(at: Point(8, 8)), on: button)
            try s.settle { try background() == .color(.steelBlue) }
            s.expect(try background(), .color(.steelBlue), "its own again")
        }
    }
}
