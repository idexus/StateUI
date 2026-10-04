// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What one state holds on the image: numbers, one lane each, or text. This
/// library's own.
public enum StateCarried: Equatable, Sendable {
    /// Plain numbers, in a stated order - what almost everything is.
    case lanes([Double])

    /// Text, which has no lanes: it is dirty or it is not.
    case text(String)
}
