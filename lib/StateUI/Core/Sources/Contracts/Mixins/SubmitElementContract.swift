// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a field the user submits holds and reports: the word its key shows, and the submission.
public enum SubmitElementContract: Tier {
    /// The tier's own name.
    public static let name = "SubmitElement"

    /// The user submitted it - the return key, the search key.
    public static let submitted = ElementEvent<Self, Void>("submitted", layer: .native)

    /// What the keyboard's return key is captioned; Next hands the keyboard on to the next field as it submits.
    public static let submitLabel = ElementProperty<Self, SubmitLabel>("submitLabel", layer: .adaptive)

    /// The tier's own members.
    public static let members: [any ContractMember] = [submitted, submitLabel]
}
