// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a build is compiled for, by StateUI's canonical names; each host's adapter says it in its own tools' words.
public enum Architecture: String, Codable, CaseIterable, Sendable {
    case arm64
    case x86_64
    case armv7
    case x86
    case wasm32
}
