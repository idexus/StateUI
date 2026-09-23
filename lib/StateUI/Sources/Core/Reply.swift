// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What the host answered an act with: values to resume with, or a reason to throw.
enum Reply: Equatable, Sendable {
    /// The act ran; these are the values it returned - empty for a method
    /// that returns nothing.
    case finished([PropValue])

    /// The act could not be performed, and this is why.
    case failed(String)
}
