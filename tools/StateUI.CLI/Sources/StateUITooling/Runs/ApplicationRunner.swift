// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// An application built, started on its destination - held for a debugger where asked - and followed until it
/// ends; cancelling the run ends the application and every process its launch started. The run is the session: one
/// operation, its output the application's, its `started` event what a debugger attaches by.
/// Design: docs/design/tooling/runs.md
public struct ApplicationRunner: Sendable {
    private let builder: ApplicationBuilder

    /// A runner building with `builder`.
    public init(builder: ApplicationBuilder = ApplicationBuilder()) {
        self.builder = builder
    }

    /// Runs `request`'s application as operation `operation`.
    ///
    /// - Throws: ``ToolingError`` - a build's, `INVALID_CONFIGURATION` for a host it does not run or a release
    ///   build held for a debugger, `TOOL_FAILED` where it does not start - or `CancellationError` once stopped.
    public func run(_ request: RunRequest, in folder: URL, operation: String, reporter: RunReporter = RunReporter())
        async throws -> RunResult {
        guard request.build.host == .uikit else {
            throw ToolingError(.invalidConfiguration, "application/run starts UIKit heads; \(request.build.host.rawValue) runs from the program application/build names.")
        }
        if request.debugger, request.build.configuration == .release {
            throw ToolingError(.invalidConfiguration, "Only a debug build is held for a debugger.")
        }
        let (built, root) = try await builder.built(request.build, in: folder, operation: operation, reporter: reporter.build)
        #if os(macOS)
        guard let destination = built.destination, let bundleUri = built.bundleUri else {
            throw ToolingError(.internalError, "The build named no destination or bundle.")
        }
        let bundle = try FileURI.url(bundleUri)
        let keys = try PropertyListSerialization.propertyList(from: Data(contentsOf: bundle.appendingPathComponent("Info.plist")), format: nil)
        guard let identifier = (keys as? [String: Any])?["CFBundleIdentifier"] as? String else {
            throw ToolingError(.internalError, "\(bundle.lastPathComponent) names no identifier.")
        }
        switch destination.kind {
        case .simulator:
            let logs = root.appendingPathComponent(".stateui/operations").appendingPathComponent(operation)
            return try await SimulatorLaunch(simulator: destination, bundle: bundle, identifier: identifier, logs: logs)
                .run(built, held: request.debugger, reporter: reporter)
        case .device:
            return try await DeviceLaunch(device: destination, bundle: bundle, identifier: identifier)
                .run(built, held: request.debugger, reporter: reporter)
        case .emulator:
            throw ToolingError(.internalError, "A UIKit head has no emulator.")
        }
        #else
        _ = (built, root)
        throw ToolingError(.invalidConfiguration, "A UIKit head runs from a Mac.")
        #endif
    }
}
