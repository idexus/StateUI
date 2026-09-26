// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Cases of one kind - toggles, values, fields - which a host's suite runs as one test.
@_spi(Host) public protocol ConformanceFamily: SendableMetatype {
    /// The family's name, as its cases are reported under it.
    static var name: String { get }

    /// Its cases, in order.
    static var cases: [ConformanceCase] { get }
}
