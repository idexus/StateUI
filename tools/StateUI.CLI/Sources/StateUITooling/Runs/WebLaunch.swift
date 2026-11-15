// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if canImport(NIOPosix)
import Foundation
import NIOCore
import StateUIToolingProtocol

/// A Web head's page served from its artifact while the run lasts, opened in a browser - the system's own unless the
/// run names one, or none - what the run hands the application of the tool's environment each a parameter of the
/// page's address. A stop closes the server; the browser and its tab are the user's.
/// Design: docs/design/tooling/runs.md#on-the-web
struct WebLaunch {
    var site: URL
    var port: Int?
    var lan: Bool
    /// The browser the page opens in: `default` the system's own, `none` none, else a browser's id.
    var browser: String?
    /// What the run hands the application of the tool's environment.
    var environment: HandedEnvironment

    func run(_ built: BuildResult, reporter: RunReporter) async throws -> RunResult {
        let server = try await PageServer.start(site, port: port, lan: lan, said: { line in
            reporter.output(ProcessOutput(stream: .standardError, text: line))
        })
        let query = Self.query(of: environment)
        let url = "http://127.0.0.1:\(server.port)/\(query)"
        if lan {
            for address in Self.addresses() { reporter.build.progress("serving on the network at http://\(address):\(server.port)/\(query)") }
        }
        let launched = LaunchedApplication(build: built, process: nil, held: false, url: url)
        reporter.started(launched)
        if browser != "none" { await Browsers.open(url, in: browser ?? "default") }
        while !Task.isCancelled { try? await Task.sleep(for: .seconds(1)) }
        await server.stop()
        throw CancellationError()
    }

    /// The page address's query: what the run hands the application, each a parameter.
    static func query(of environment: HandedEnvironment) -> String {
        let parameters = environment.sorted
        return parameters.isEmpty ? "" : "?" + parameters.map { "\($0.name)=\($0.value)" }.joined(separator: "&")
    }

    /// This machine's IPv4 addresses on its networks, the loopback aside.
    static func addresses() -> [String] {
        ((try? System.enumerateDevices()) ?? []).compactMap { device in
            guard let address = device.address, case .v4 = address, let ip = address.ipAddress, !ip.hasPrefix("127.") else { return nil }
            return ip
        }.sorted()
    }
}
#endif
