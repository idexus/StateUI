// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The cases of one contract - a control's, a structure's or a tier's - which a host's suite runs as one test.
@_spi(Host) public protocol ConformanceFamily: SendableMetatype {
    /// The family's name, as its cases are reported under it.
    static var name: String { get }

    /// Its cases, in order.
    @MainActor static var cases: [ConformanceCase] { get }
}
