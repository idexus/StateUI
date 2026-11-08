// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a control whose choices open in a list of their own holds and reports: a picker, a date's and a time's.
public enum PopupElementContract: Tier {
    /// The tier's own name.
    public static let name = "PopupElement"

    /// Whether its list of choices is showing.
    public static let isOpen = ElementProperty<Self, Bool>("isOpen", layer: .native)

    /// Its list of choices has opened.
    public static let opened = ElementEvent<Self, Void>("opened", layer: .native)

    /// Its list of choices has closed - by a choice, a tap outside, or the platform.
    public static let closed = ElementEvent<Self, Void>("closed", layer: .native)

    /// The tier's own members.
    public static let members: [any ContractMember] = [isOpen, opened, closed]
}
