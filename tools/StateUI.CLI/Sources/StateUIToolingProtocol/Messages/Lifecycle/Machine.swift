// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A computer the tool runs on: its operating system and processor architecture.
public struct Machine: Codable, Equatable, Sendable {
    /// The operating system: `macos`, `linux` or `windows`.
    public var system: String
    /// The processor architecture: `arm64` or `x86_64`.
    public var architecture: String

    /// A machine of `system` on `architecture`.
    public init(system: String, architecture: String) {
        self.system = system
        self.architecture = architecture
    }
}
