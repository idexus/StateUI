// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import Foundation
import StateUIToolingProtocol

/// A UIKit head installed on a device and started there, `devicectl` following its console until it ends; a stop
/// ends the application on the device, then `devicectl`.
/// Design: docs/design/tooling/runs.md#on-a-device
struct DeviceLaunch {
    var device: Destination
    var bundle: URL
    var identifier: String
    /// What the run hands the application of the tool's environment.
    var environment: HandedEnvironment

    /// `devicectl`'s words handing the application `environment`, a JSON object of its variables; none where it is
    /// empty.
    static func handing(_ environment: HandedEnvironment) -> [String] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard !environment.variables.isEmpty, let json = try? encoder.encode(environment.variables) else { return [] }
        return ["--environment-variables", String(decoding: json, as: UTF8.self)]
    }

    func run(_ built: BuildResult, held: Bool, reporter: RunReporter) async throws -> RunResult {
        reporter.build.progress("installing on \(device.name)")
        try await ToolStep.run(.name("xcrun"), ["devicectl", "device", "install", "app", "--device", device.id, bundle.path], limit: .seconds(600))
        reporter.build.progress("starting \(identifier)")
        let (launches, launching) = AsyncStream<Void>.makeStream()
        let console = Task {
            defer { launching.finish() }
            return try await ProcessRunner().run(
                ProcessRequest(.name("xcrun"), arguments: ["devicectl", "device", "process", "launch", "--console", "--terminate-existing"]
                    + (held ? ["--start-stopped"] : []) + Self.handing(environment) + ["--device", device.id, identifier]),
                output: { line in
                    if line.text.hasPrefix("Launched application") { launching.yield() }
                    reporter.output(line)
                })
        }
        var process: Int?
        do {
            try await withTaskCancellationHandler {
                var started = false
                for await _ in launches {
                    started = true
                    break
                }
                guard started else {
                    _ = try await console.value
                    try Task.checkCancellation()
                    throw ToolingError(.toolFailed, "\(identifier) did not start on \(device.name); devicectl's words above say why.")
                }
                process = await find()
                guard process != nil || !held else {
                    throw ToolingError(.toolFailed, "\(identifier) started on \(device.name), but devicectl does not list its process.")
                }
                reporter.started(LaunchedApplication(build: built, process: process, held: held))
                _ = try await console.value
                try Task.checkCancellation()
            } onCancel: {
                launching.finish()
                console.cancel()
            }
        } catch {
            if let process {
                await ToolStep.regardless(.name("xcrun"), ["devicectl", "device", "process", "terminate", "--device", device.id, "--pid", "\(process)", "--kill"])
            }
            console.cancel()
            _ = try? await console.value
            throw error
        }
        return RunResult(launched: LaunchedApplication(build: built, process: process, held: held), exitStatus: nil)
    }

    /// The process the application runs as on the device: its program found among the device's processes.
    private func find() async -> Int? {
        let product = bundle.deletingPathExtension().lastPathComponent
        let listed = FileManager.default.temporaryDirectory.appendingPathComponent("processes-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: listed) }
        for _ in 0..<20 where !Task.isCancelled {
            _ = await ToolOutput.standardOutput(
                .name("xcrun"), ["devicectl", "device", "info", "processes", "--device", device.id, "--quiet", "--json-output", listed.path])
            if let data = try? Data(contentsOf: listed), let found = Self.process(of: product, in: data) { return found }
            try? await Task.sleep(for: .milliseconds(500))
        }
        return nil
    }

    /// The process whose program is `<product>.app/<product>` in what `devicectl device info processes` wrote.
    static func process(of product: String, in json: Data) -> Int? {
        guard let root = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let running = (root["result"] as? [String: Any])?["runningProcesses"] as? [[String: Any]]
        else { return nil }
        return running.first { ($0["executable"] as? String)?.hasSuffix("/\(product).app/\(product)") == true }?["processIdentifier"] as? Int
    }
}
#endif
