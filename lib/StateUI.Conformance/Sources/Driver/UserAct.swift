// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUI

/// What a user does to a control, a page or a window, which a driver does through its toolkit's own path.
public enum UserAct: Equatable, Sendable, CustomStringConvertible {
    /// A button's click, a menu's or a toolbar's item chosen.
    case activate
    /// A switch's, a check box's or a radio button's turn; a split view's sidebar shown or hidden.
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
    /// A choice picked from a list, or a tab, by its place.
    case choose(Int)
    /// A picker's list, a date's calendar or a time's clock opened; a map's pin's details.
    case open
    /// A picker's list, a date's calendar or a time's clock closed; a window closed.
    case close
    /// A day picked from a date's calendar.
    case pickDate(CalendarDate)
    /// A time of day picked from a time's clock.
    case pickTime(ClockTime)
    /// A pointer pressed down on the element, at a point of its own.
    case pressDown(at: Point)
    /// The pointer pressed down moved to a point of the element's.
    case drag(to: Point)
    /// The pointer pressed down let go, at a point of the element's.
    case lift(at: Point)
    /// The pointer moved over the element to a point of its own, coming in first where it was not over it.
    case hover(at: Point)
    /// The pointer left the element.
    case leave
    /// A quick run of taps on the element.
    case tap(count: Int)
    /// A press dragged across the element by an offset, and let go.
    case pan(by: Point)
    /// Two fingers spreading or closing over the element, by a scale since the last, about a point of it given as a
    /// share of its size.
    case pinch(scale: Double, at: Point)
    /// The element dragged onto the one of the id given, and dropped there - across the one of the other id first,
    /// in over it and out again, where one is given.
    case dragAndDrop(onto: String, across: String? = nil)
    /// A scroll view scrolled to an offset.
    case scroll(to: Point)
    /// The keyboard moved to the element.
    case focus
    /// The way back taken: a navigation's page, or the top modal page, gone.
    case goBack
    /// A window put away.
    case minimize
    /// A window put away brought back.
    case restore
    /// Another application brought in front of this one.
    case switchAway
    /// This application brought in front again.
    case switchBack
    /// A window of the application brought in front of its others, as the user picks it.
    case bringToFront
    /// The question the window shows answered by its button of that caption, its field first holding the words.
    case answer(String, typing: String? = nil)
    /// A web view's content ended, as the platform ends it when its process goes.
    case endContent

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
        case .open: "open"
        case .close: "close"
        case .pickDate: "pickDate"
        case .pickTime: "pickTime"
        case .pressDown: "pressDown"
        case .drag: "drag"
        case .lift: "lift"
        case .hover: "hover"
        case .leave: "leave"
        case .tap: "tap"
        case .pan: "pan"
        case .pinch: "pinch"
        case .dragAndDrop: "dragAndDrop"
        case .scroll: "scroll"
        case .focus: "focus"
        case .goBack: "goBack"
        case .minimize: "minimize"
        case .restore: "restore"
        case .switchAway: "switchAway"
        case .bringToFront: "bringToFront"
        case .switchBack: "switchBack"
        case .answer: "answer"
        case .endContent: "endContent"
        }
    }
}
