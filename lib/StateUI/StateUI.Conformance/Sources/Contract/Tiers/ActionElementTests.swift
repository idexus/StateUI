// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `ActionElementContract` on a host: an item that acts - a menu's, a toolbar's - chosen runs its handler, and stands
/// marked as the role the tree gives it; each case made for every element wearing the tier.
@_spi(Host) public enum ActionElementTests: ConformanceFamily {
    public static let name = "ActionElement"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(ActionElementContract.self).flatMap { element in
            [
                chosen(element),
                Aspects.holds(ActionElementContract.role, on: element, ActionRole.normal, then: .destructive),
            ]
        }
    }

    /// An item chosen runs its handler.
    @MainActor
    static func chosen(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).anItemChosenRunsItsHandler", proves: [
            Covered(ActionElementContract.clicked, on: element),
        ]) { s in
            let heard = Received<String>()
            s.start {
                Chosen.page(element) { enabled in
                    (enabled ? "on" : "off", { @MainActor in heard.values.append(enabled ? "on" : "off") })
                }
            }

            try s.perform(.activate, on: s.element("on"))
            s.settle { heard.values == ["on"] }
            s.expect(heard.values, ["on"], "the item chosen ran its handler")
        }
    }
}
