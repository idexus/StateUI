// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// The search path a program found by name comes from.
public struct SearchPath: Sendable {
    private let environment: [String: String]

    /// The search path of `environment`: this process's own unless given.
    public init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.environment = environment
    }

    /// Where `name` stands on the search path - with Windows' own extensions for a program.
    public func find(_ name: String) -> URL? {
        #if os(Windows)
        let separator: Character = ";"
        let extensions = (environment["PATHEXT"] ?? ".EXE;.CMD;.BAT").split(separator: ";").map { $0.lowercased() }
        #else
        let separator: Character = ":"
        let extensions = [""]
        #endif
        let path = environment["PATH"] ?? environment["Path"] ?? ""
        for folder in path.split(separator: separator) where !folder.isEmpty {
            for suffix in extensions {
                let candidate = URL(fileURLWithPath: String(folder)).appendingPathComponent(name + suffix)
                if FileManager.default.isExecutableFile(atPath: candidate.path) { return candidate }
            }
        }
        return nil
    }
}
