// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One of a program's two output streams.
public enum StandardStream: String, Codable, Sendable, CaseIterable {
    /// Standard output.
    case stdout
    /// Standard error.
    case stderr
}
