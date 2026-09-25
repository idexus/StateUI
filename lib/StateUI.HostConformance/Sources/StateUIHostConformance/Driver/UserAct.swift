// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a user does to a control, which a driver does through its toolkit's own path.
public enum UserAct: Equatable, Sendable, CustomStringConvertible {
    /// A button's click.
    case activate
    /// A switch's, a check box's or a radio button's turn.
    case toggle
    /// A slider's thumb moved to a value.
    case slide(to: Double)
    /// A stepper's button, up or down.
    case step(up: Bool)
    /// Words typed into a box of numbers and taken, as Enter takes them.
    case enterWords(String)
    /// A field's words, as typing leaves them.
    case type(String)
    /// Enter pressed in a field.
    case submit
    /// A choice picked from a list, by its place.
    case choose(Int)

    /// The act's name, as a driver says what it cannot do.
    public var description: String {
        switch self {
        case .activate: "activate"
        case .toggle: "toggle"
        case .slide: "slide"
        case .step: "step"
        case .enterWords: "enterWords"
        case .type: "type"
        case .submit: "submit"
        case .choose: "choose"
        }
    }
}
