// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// The folder SwiftPM laid a build's products in, as `swift build --show-bin-path` says it - a step of the build.
/// Design: docs/design/tooling/builds.md#where-swiftpm-laid-a-build
enum ProductFolder {
    /// Where SwiftPM laid the build `compiler` ran with `arguments` - its package, scratch, configuration, triple and
    /// SDK: the last line of its standard output.
    ///
    /// - Throws: ``ToolingError`` `TOOL_FAILED` with what SwiftPM said and how it ended, where it said no folder.
    static func of(
        _ compiler: ProcessExecutable, placing arguments: [String], environment: ProcessEnvironment = .inherited
    ) async throws -> URL {
        let said: String
        do {
            said = try await ToolStep.run(compiler, ["build", "--show-bin-path"] + arguments, environment: environment,
                                          limit: .seconds(300))
        } catch let refused as ToolingError {
            throw ToolingError(.toolFailed, "SwiftPM did not say where it laid the build: \(refused.message)")
        }
        guard let folder = said.split(separator: "\n").last.map({ String($0).trimmingCharacters(in: .whitespaces) }),
              !folder.isEmpty
        else { throw ToolingError(.toolFailed, "SwiftPM did not say where it laid the build: it printed no folder.") }
        return URL(fileURLWithPath: folder)
    }
}
