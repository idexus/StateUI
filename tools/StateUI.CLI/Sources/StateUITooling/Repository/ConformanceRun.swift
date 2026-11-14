// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// A host's conformance families run whole - the stale ones, the ones named, or every one - their verdicts held to
/// the marks or recorded, then the control dictionary and the platform contract held to them or rendered again: one
/// operation, each a phase of its own.
/// Design: docs/design/tooling/repository.md#a-conformance-run
public struct ConformanceRun: Sendable {
    private let checkout: URL
    private let suites: HostSuite
    private let tools: ToolResolver

    /// The runs of the checkout at `checkout`.
    public init(checkout: URL, environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.checkout = checkout
        suites = HostSuite(checkout: checkout, environment: environment)
        tools = ToolResolver(environment: environment)
    }

    /// Runs `host`'s families `selection` takes - on the device `device` names, for UIKit and Android - holding their
    /// verdicts, or writing them where `record`.
    ///
    /// - Throws: ``ToolingError`` `INVALID_CONFIGURATION` for a family no contract declares.
    public func run(_ host: HostFamily, selection: ConformanceSelection, record: Bool, device: String? = nil, reporter: BuildReporter) async throws
        -> SuiteResult {
        let status = try await ConformanceMetadata(checkout: checkout, tools: tools).status(of: host, reporter: reporter)
        let known = Set(status.families.map(\.name))
        if case .families(let names) = selection, let unknown = names.first(where: { !known.contains($0) }) {
            throw ToolingError(.invalidConfiguration, "No conformance family \(unknown): `stateui repo conformance status` lists them.")
        }
        let stale = status.stale.map(\.name)
        if selection == .changed, stale.isEmpty {
            return SuiteResult(suite: "conformance:\(host.rawValue)", phases: [SuiteResult.Phase(name: "every family fresh", passed: true)])
        }
        // A host whose driver reads the repository tells its stale families itself; Android's device reads none.
        let families: [String]? = switch selection {
        case .all: nil
        case .families(let names): names
        case .changed: host == .android ? stale : nil
        }
        reporter.progress("running \(host.folder)'s conformance families: \(families?.joined(separator: ", ") ?? (selection == .changed ? "the stale ones" : "every one"))")
        let suite = try await suites.run(
            host, filter: Self.filter(for: host, families: families), device: device, recording: record,
            staleOnly: selection == .changed && host != .android,
            revisions: Dictionary(uniqueKeysWithValues: status.families.map { ($0.name, $0.revision) }), reporter: reporter)
        var phases = suite.phases
        phases.append(try await Handbook(checkout: checkout, tools: tools).documents(update: record, reporter: reporter))
        return SuiteResult(suite: "conformance:\(host.rawValue)", phases: phases)
    }

    /// What a host's suite is filtered by for `families` - every family where none are named: `swift test`'s
    /// expression on a desktop host, each family's test and its parts; the names the test application looks for on
    /// UIKit and Android; the families by name on the Web.
    static func filter(for host: HostFamily, families: [String]?) -> String {
        let tests = "\(host.folder)ConformanceTests"
        // Every family, and what the host declares it realizes - `exports/<host>.txt` - with them.
        guard let families else {
            switch host {
            case .web: return tests
            case .uikit, .android: return "\(tests),\(host.folder)DeclarationExportTests"
            default: return "\(tests)|\(host.folder)DeclarationExportTests"
            }
        }
        switch host {
        case .uikit, .android:
            return families.map { "\(tests).test\($0)" }.joined(separator: ",")
        case .web:
            return families.joined(separator: ",")
        default:
            return "\(tests)/test(\(families.joined(separator: "|")))[0-9]*$"
        }
    }
}
