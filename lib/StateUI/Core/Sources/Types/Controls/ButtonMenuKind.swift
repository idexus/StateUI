// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// How a button's menu opens: by the button's click, by an arrow of its own, or held.
///
///     Button("Save")
///         .onClicked { save() }
///         .menu(.held) { MenuItem("Save as…").onClicked { saveAs() } }
public enum ButtonMenuKind: Int32, Sendable, CaseIterable {
    /// A click opens the menu where the button has no click of its own, an arrow pointing down saying so; else the
    /// button splits, as `.split`.
    case automatic = 0

    /// The button splits: its click its own, an arrow of its own opening the menu.
    case split = 1

    /// The click is the button's own and no arrow shows: holding the button down opens the menu, as the platform
    /// holds - a long press, a press and hold, or a right click.
    case held = 2
}

extension ButtonMenuKind: HostRepresentable {}
