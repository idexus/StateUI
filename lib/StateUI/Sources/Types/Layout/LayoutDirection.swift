// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// Which way a view lays its content out, and which edge it starts from -
/// what `.layoutDirection` takes.
///
/// The point of it is a language written right to left: a view told
/// `.rightToLeft` mirrors its layout, so a stack fills from the right and a
/// label's natural alignment moves with it.
public enum LayoutDirection: Int32, Sendable {
    /// Whatever the view above says, which is how a view inherits the
    /// application's. The default.
    case inherited = 0

    /// Left to right, whatever the view above says.
    case leftToRight = 1

    /// Right to left, whatever the view above says.
    case rightToLeft = 2
}

extension LayoutDirection: HostRepresentable {}
extension LayoutDirection: StateChoice {}
