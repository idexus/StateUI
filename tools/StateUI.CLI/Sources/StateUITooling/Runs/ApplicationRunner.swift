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
        try Self.refuse(request)
        var request = request
        request.build = try ApplicationBuilder.chosen(request.build, in: folder)
        try Self.refuse(request)
        if request.build.host == .android {
            return try await runAndroid(request, in: folder, operation: operation, reporter: reporter)
        }
        if request.build.host == .web {
            #if canImport(NIOPosix)
            let (built, _) = try await builder.built(request.build, in: folder, operation: operation, reporter: reporter.build)
            return try await WebLaunch(
                site: try FileURI.url(built.folderUri), port: request.port, lan: request.lan ?? false, browser: request.build.device,
                environment: HandedEnvironment(of: ProcessInfo.processInfo.environment)
            ).run(built, reporter: reporter)
            #else
            throw ToolingError(.invalidConfiguration, "A Web head's page is served on macOS and Linux.")
            #endif
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
            return try await SimulatorLaunch(
                simulator: destination, bundle: bundle, identifier: identifier, logs: logs,
                environment: HandedEnvironment(of: ProcessInfo.processInfo.environment))
                .run(built, held: request.debugger, reporter: reporter)
        case .device:
            return try await DeviceLaunch(
                device: destination, bundle: bundle, identifier: identifier,
                environment: HandedEnvironment(of: ProcessInfo.processInfo.environment))
                .run(built, held: request.debugger, reporter: reporter)
        case .emulator, .browser, .guest:
            throw ToolingError(.internalError, "A UIKit head runs on no \(destination.kind.rawValue).")
        }
        #else
        _ = (built, root)
        throw ToolingError(.invalidConfiguration, "A UIKit head runs from a Mac.")
        #endif
    }

    /// Refuses, before anything is read or built, a run of a host it does not start - another runs from the program
    /// its build names - and a release build held for a debugger; a request naming no host yet passes.
    private static func refuse(_ request: RunRequest) throws {
        guard let host = request.build.host else { return }
        guard [.uikit, .android, .web].contains(host) else {
            throw ToolingError(.invalidConfiguration, "application/run starts UIKit, Android and Web heads; \(host.rawValue) runs from the program application/build names.")
        }
        if request.debugger, request.build.configuration == .release {
            throw ToolingError(.invalidConfiguration, "Only a debug build is held for a debugger.")
        }
    }

    /// An Android head run on the device or emulator the request names - a virtual device not running booted first,
    /// so the build is for its ABI.
    private func runAndroid(_ request: RunRequest, in folder: URL, operation: String, reporter: RunReporter) async throws -> RunResult {
        let environment = ProcessInfo.processInfo.environment
        let tools = AndroidTools(environment: environment)
        let destinations = AndroidDestinations(tools: tools)
        var destination = try AndroidDestinations.choose(request.build.device, from: await destinations.list(), environment: environment)
        if !destination.booted, destination.kind == .emulator {
            destination = try await destinations.boot(destination.id, reporter: reporter.build)
        }
        var build = request.build
        build.device = destination.id
        let (built, _) = try await builder.built(build, in: folder, operation: operation, reporter: reporter.build)
        guard let apk = built.bundleUri.flatMap({ try? FileURI.url($0) }) else {
            throw ToolingError(.internalError, "The build named no APK.")
        }
        let (package, activity) = try await AndroidHead.badging(of: apk, tools: tools)
        let ndk = request.debugger ? tools.ndk(for: await tools.swift()?.sdk) : nil
        return try await AndroidLaunch(
            device: built.destination ?? destination, apk: apk, package: package, activity: activity, ndk: ndk, tools: tools,
            environment: HandedEnvironment(of: environment)).run(built, debugger: request.debugger, reporter: reporter)
    }
}
