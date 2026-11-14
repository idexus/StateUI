// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// Each application's release Web module held within its budget, gzipped - what a page downloads: past it fails, a
/// twentieth or more under it is said, for the budget to come down with it.
/// Design: docs/design/tooling/repository.md#the-web-modules-sizes
struct WebSizes {
    let checkout: URL

    /// The application and its budget, in bytes of the module gzipped at level 9. A budget is raised only in the
    /// change that grows the module, with the reason (docs/design/platforms/web/runtime.md, The module's size).
    static let budgets = [("HelloWorld", 5_060_000), ("Gallery", 6_170_000)]

    func run(reporter: BuildReporter) async throws -> [SuiteResult.Phase] {
        var phases: [SuiteResult.Phase] = []
        for (application, budget) in Self.budgets {
            let folder = checkout.appendingPathComponent("apps/\(application)")
            let built = try await ApplicationBuilder().build(
                    BuildRequest(projectUri: FileURI.string(folder), host: .web, configuration: .release),
                    in: folder, operation: "sizes-\(UUID().uuidString.lowercased())", reporter: reporter)
            let module = try FileURI.url(built.folderUri).appendingPathComponent("\(application)Web.wasm")
            let size = try await Self.gzipped(module)
            let words = size > budget ? "over its budget of \(budget)"
                : size * 20 <= budget * 19 ? "a twentieth or more under its budget of \(budget) - lower it" : "within its budget of \(budget)"
            reporter.output(ProcessOutput(stream: .standardOutput, text: "\(application): \(size) bytes gzipped, \(words)"))
            phases.append(SuiteResult.Phase(name: "size \(application)", passed: size <= budget))
        }
        return phases
    }

    /// `file`'s size gzipped at level 9, no name or time in it.
    static func gzipped(_ file: URL) async throws -> Int {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("stateui-gzip-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let copy = folder.appendingPathComponent(file.lastPathComponent)
        try FileManager.default.copyItem(at: file, to: copy)
        try await ToolStep.run(.name("gzip"), ["-9", "-n", copy.path], limit: .seconds(300))
        let attributes = try FileManager.default.attributesOfItem(atPath: copy.path + ".gz")
        return (attributes[.size] as? NSNumber)?.intValue ?? 0
    }
}
