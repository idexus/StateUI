// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What a user does to a view - a click, a toggle, words typed - which a test's window does as the user does.
public enum UserAct: Equatable, Sendable, CustomStringConvertible {
    /// A button's click, a link's, a menu's item chosen.
    case activate
    /// A quick run of taps on the view.
    case tap(count: Int)
    /// A switch's or a check box's turn.
    case toggle
    /// A field's words, as typing leaves them.
    case type(String)
    /// Enter pressed in a field.
    case submit
    /// The keyboard moved to the view.
    case focus
    /// A slider's thumb moved to a value.
    case slide(to: Double)
    /// A stepper's button, up or down: one step, which a stepper at the end of its range does not take.
    case step(up: Bool)
    /// A picker's choice, by the words its user sees.
    case choose(String)
    /// A day picked from a date picker's calendar.
    case pickDate(CalendarDate)
    /// A time of day picked from a time picker's clock.
    case pickTime(ClockTime)
    /// A color picked in a color picker's panel.
    case pickColor(Color)
    /// One of the view's actions performed, by its words, as a screen reader performs it.
    case performAccessibilityAction(String)
    /// The view stepped up or down as a screen reader steps it.
    case adjust(AccessibilityAdjustment)

    /// The act's name, as a failure says what cannot be done.
    public var description: String {
        switch self {
        case .activate: "activate"
        case .tap: "tap"
        case .toggle: "toggle"
        case .type: "type"
        case .submit: "submit"
        case .focus: "focus"
        case .slide: "slide"
        case .step: "step"
        case .choose: "choose"
        case .pickDate: "pickDate"
        case .pickTime: "pickTime"
        case .pickColor: "pickColor"
        case .performAccessibilityAction: "performAccessibilityAction"
        case .adjust: "adjust"
        }
    }

    /// The act as a driver does it to `element`: a choice at the one place among the picker's options that says its
    /// words.
    /// - Throws: `DriverCannot` where the picker offers no choice of those words, or two.
    /// Design: docs/design/host/testing.md#the-acts-a-window-offers
    @MainActor func driven(on element: MountedElement) throws -> StateUIHost.UserAct {
        switch self {
        case .activate: return .activate
        case .tap(let count): return .tap(count: count)
        case .toggle: return .toggle
        case .type(let words): return .type(words)
        case .submit: return .submit
        case .focus: return .focus
        case .slide(let value): return .slide(to: value)
        case .step(let up): return .step(up: up)
        case .choose(let words):
            let offered = element.value(PickerContract.options.token)?.strings ?? []
            let places = offered.indices.filter { offered[$0] == words }
            guard places.count == 1 else {
                throw DriverCannot(
                    "choose \"\(words)\" on \(element.type.name)",
                    because: places.isEmpty ? "it offers no such choice" : "it offers \(places.count) of them")
            }
            return .choose(places[0])
        case .pickDate(let day): return .pickDate(day)
        case .pickTime(let time): return .pickTime(time)
        case .pickColor(let color): return .pickColor(color)
        case .performAccessibilityAction(let name): return .performAccessibilityAction(name)
        case .adjust(let step): return .adjust(step)
        }
    }
}
