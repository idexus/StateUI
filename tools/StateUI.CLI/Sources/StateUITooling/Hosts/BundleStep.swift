// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUIToolingProtocol

/// A program a bundle's assembly runs - `codesign`, `actool`, `iconutil` - which must succeed.
enum BundleStep {
    /// Runs `tool` with `arguments`.
    ///
    /// - Throws: ``ToolingError`` `TOOL_FAILED` with the last of what it said, where it failed.
    static func run(_ tool: String, _ arguments: [String]) async throws {
        let said = Gathered()
        let outcome = try await ProcessRunner().run(ProcessRequest(.name(tool), arguments: arguments, timeout: .seconds(120)), output: said.add)
        guard outcome.succeeded else {
            let words = (said.lines(of: .standardError) + said.lines(of: .standardOutput)).suffix(5).joined(separator: "\n")
            throw ToolingError(.toolFailed, "\(tool) refused:\n\(words)")
        }
    }
}
