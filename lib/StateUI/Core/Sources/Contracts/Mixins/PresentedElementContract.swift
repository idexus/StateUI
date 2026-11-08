// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a page shown over the one beneath it holds and reports: a sheet, a popover.
public enum PresentedElementContract: Tier {
    /// The tier's own name.
    public static let name = "PresentedElement"

    /// Whether it shows: the application presents it, and the user's dismissal writes false.
    public static let isPresented = ElementProperty<Self, Bool>("isPresented", layer: .adaptive)

    /// The user dismissed it - a swipe, Escape, a tap outside, the way back.
    public static let isPresentedChanged = ElementEvent<Self, Bool>("isPresentedChanged", layer: .adaptive)

    /// The tier's own members.
    public static let members: [any ContractMember] = [isPresented, isPresentedChanged]
}
