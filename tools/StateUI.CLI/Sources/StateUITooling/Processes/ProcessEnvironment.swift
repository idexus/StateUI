// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The environment a program starts with: this tool's own, less the variables removed, with the ones set.
public struct ProcessEnvironment: Sendable, Equatable {
    /// The variables taken away.
    public private(set) var removed: Set<String> = []
    /// The variables given, by name.
    public private(set) var set: [String: String] = [:]

    /// This tool's environment as it stands.
    public static let inherited = ProcessEnvironment()

    /// This environment without `names`.
    public func removing(_ names: String...) -> ProcessEnvironment {
        var environment = self
        for name in names {
            environment.removed.insert(name)
            environment.set[name] = nil
        }
        return environment
    }

    /// This environment with `name` set to `value`.
    public func setting(_ name: String, to value: String) -> ProcessEnvironment {
        var environment = self
        environment.removed.remove(name)
        environment.set[name] = value
        return environment
    }
}
