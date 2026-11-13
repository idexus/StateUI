// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How a build is compiled: for debugging, or optimized for release.
public enum BuildConfiguration: String, Codable, CaseIterable, Sendable {
    case debug
    case release
}
