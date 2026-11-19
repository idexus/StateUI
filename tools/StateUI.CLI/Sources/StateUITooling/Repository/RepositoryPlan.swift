// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// The owner packages' suites run in their order, each apart: `portable`, those every machine runs - the library,
/// the host layer, the conformance runner, application testing, the Gallery, HelloWorld, the tool; `native`, the
/// host suites this machine runs - on a Mac the applications built as AppKit heads too - a suite it cannot listed
/// with why. A suite failing never stops those after it.
/// Design: docs/design/tooling/repository.md#a-plan
public struct RepositoryPlan: Sendable {
    /// The portable suites, in their order: an id and the package it tests.
    static let portable = [
        ("core", "."), ("host-layer", "lib/StateUI/StateUI.Host"), ("conformance", "lib/StateUI/StateUI.Conformance"),
        ("testing", "lib/StateUI/StateUI.Testing"), ("gallery", "apps/Gallery"), ("helloworld", "apps/HelloWorld"),
        ("tool", "tools/StateUI.CLI"),
    ]

    /// The native suites a machine of `system` runs, in the matrix's order: each host's, and after AppKit's the
    /// applications built as AppKit heads (`apps:appkit`).
    static func native(on system: String) -> [String] {
        switch system {
        case "macos": ["host:appkit", "apps:appkit", "host:uikit", "host:android", "host:web"]
        case "linux": ["host:gtk", "host:web"]
        case "windows": ["host:winui"]
        default: []
        }
    }

    private let checkout: URL
    private let suites: HostSuite
    private let tools: ToolResolver

    /// The plans of the checkout at `checkout`.
    public init(checkout: URL, environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.checkout = checkout
        suites = HostSuite(checkout: checkout, environment: environment)
        tools = ToolResolver(environment: environment)
    }

    /// The device UIKit's and Android's suites take of `named`: the host whose destinations hold it by id, UDID or name
    /// - the other taking its own - none where nothing is named.
    ///
    /// - Throws: ``ToolingError`` `INVALID_CONFIGURATION` where neither host's destinations hold it.
    static func devices(_ named: String?, uikit: [Destination], android: [Destination]) throws -> [HostFamily: String] {
        guard let named else { return [:] }
        func holds(_ listed: [Destination]) -> Bool { listed.contains { [$0.id, $0.udid, $0.name].contains(named) } }
        let chosen = [(HostFamily.uikit, holds(uikit)), (.android, holds(android))].filter(\.1)
        guard !chosen.isEmpty else {
            throw ToolingError(.invalidConfiguration, "No UIKit or Android device here is \(named) - `stateui devices` lists them.")
        }
        return Dictionary(uniqueKeysWithValues: chosen.map { ($0.0, named) })
    }

    private static func listed(_ host: HostFamily) async -> [Destination] {
        (try? await ToolingService().listDestinations(of: host).destinations) ?? []
    }

    /// The ids `kind` holds on this machine.
    public static func suites(of kind: PlanKind) -> [String] {
        kind == .portable ? portable.map(\.0) : native(on: Machine.current.system)
    }

    /// Runs `kind`'s suites - `only` that one where named - each a phase or phases under its id; UIKit's or Android's
    /// suite on the device `device` names where it is that host's, an Android one with no device running listed as not
    /// run.
    public func run(_ kind: PlanKind, only: String? = nil, device: String? = nil, reporter: BuildReporter) async throws -> SuiteResult {
        let ids = Self.suites(of: kind)
        if let only, !ids.contains(only) {
            throw ToolingError(.invalidConfiguration, "The \(kind.rawValue) plan here holds \(ids.joined(separator: ", ")); not \(only).")
        }
        let devices = device != nil && ids.contains(where: { $0 == "host:uikit" || $0 == "host:android" })
            ? try Self.devices(device, uikit: await Self.listed(.uikit), android: await Self.listed(.android)) : [:]
        var phases: [SuiteResult.Phase] = []
        for id in ids where only == nil || only == id {
            reporter.progress("suite \(id)")
            if kind == .portable, let package = Self.portable.first(where: { $0.0 == id })?.1 {
                let environment = ProcessEnvironment.inherited.removing(
                    "STATEUI_UPDATE_EXPORTS", "STATEUI_UPDATE_DOCS", "STATEUI_UPDATE_SAMPLES", "STATEUI_STALE_ONLY")
                let passed = try await TestRun.swift(
                    tools.swift, ["test", "--package-path", checkout.appendingPathComponent(package).path], environment, reporter)
                phases.append(SuiteResult.Phase(name: id, passed: passed))
                continue
            }
            if id == "apps:appkit" {
                for (name, package) in Self.portable where package.hasPrefix("apps/") {
                    let application = TestSuiteDescription(
                        id: package, detail: "", kind: .package, packageUri: FileURI.string(checkout.appendingPathComponent(package)), host: .appkit)
                    let ran = try await TestRunner(tools: tools).run(application, device: nil, checkout: checkout, reporter: reporter)
                    phases.append(SuiteResult.Phase(name: "\(id) \(name)", passed: ran.passed))
                }
                continue
            }
            guard let host = HostFamily(rawValue: String(id.dropFirst("host:".count))) else { continue }
            do {
                let ran = try await suites.run(host, device: devices[host], reporter: reporter)
                phases += ran.phases.map { SuiteResult.Phase(name: "\(id) \($0.name)", passed: $0.passed) }
            } catch let error as ToolingError where error.code == .invalidConfiguration || error.code == .missingToolchain {
                reporter.output(ProcessOutput(stream: .standardError, text: "\(id) not run: \(error.message)"))
                phases.append(SuiteResult.Phase(name: "\(id) not run", passed: false))
            }
        }
        return SuiteResult(suite: "plan:\(kind.rawValue)", phases: phases)
    }
}
