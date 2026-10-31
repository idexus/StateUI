// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What the relay hears on an element for the host, read from one DOM event or more. It crosses as a number, so no
/// event name - the page's, a custom element's - ever means one.
/// Design: docs/design/platforms/web/runtime.md#the-relay
enum WebHearing: Int32, CaseIterable {
    /// Return pressed, but for one that commits an input method's words.
    case enter = 0

    /// The keyboard coming into the element or anything in it, or leaving it all: the event's one number 1 or 0.
    case within

    /// A step up or down from the keyboard's arrows, its direction the event's one number.
    case steps

    /// A click on an item, but for one on a control inside it, which is the control's.
    case itemTap

    /// A popover taken down: by the browser - a click beside it, Escape - or by the program.
    case closed

    /// The user asking a modal dialog to close, which closes only as the tree says.
    case dismiss

    /// A key going down before the element holding the keyboard has it, told as a shortcut's is.
    case key

    /// A key pressed for a shortcut.
    case shortcut

    /// Return or Space pressed on the element itself.
    case activate

    /// A press on the element, the pointer the element's until it lets go - but for one begun on a control inside,
    /// which is the control's - told at each phase (`WebRelay.eventPress`).
    case press
}
