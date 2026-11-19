// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if canImport(NIOPosix)
import Foundation
import NIOCore
import StateUIToolingProtocol

/// A Web head's page served from its artifact while the run lasts, opened in a browser - the system's own unless the
/// run names one, or none - what the run hands the application of the tool's environment each a parameter of the
/// page's address; readied for a debugger, opened by none, the browser's debugger told how to start it on the page -
/// in Safari opened by the run, LLDB told the page's process.
/// A stop closes the server; the browser and its tab are the user's.
/// Design: docs/design/tooling/runs.md#on-the-web
struct WebLaunch {
    var site: URL
    var port: Int?
    var lan: Bool
    /// The browser the page opens in: `default` the system's own, `none` none, else a browser's id.
    var browser: String?
    /// What the run hands the application of the tool's environment.
    var environment: HandedEnvironment
    /// The browser whose debugger starts on the page, where the run readies one.
    var debugged: Destination?

    func run(_ built: BuildResult, reporter: RunReporter) async throws -> RunResult {
        let server = try await PageServer.start(site, port: port, lan: lan, said: { line in
            reporter.output(ProcessOutput(stream: .standardError, text: line))
        })
        let query = Self.query(of: environment)
        let url = "http://127.0.0.1:\(server.port)/\(query)"
        if lan {
            for address in Self.addresses() { reporter.build.progress("serving on the network at http://\(address):\(server.port)/\(query)") }
        }
        do {
            try await started(built, url: url, reporter: reporter)
        } catch {
            await server.stop()
            throw error
        }
        while !Task.isCancelled { try? await Task.sleep(for: .seconds(1)) }
        await server.stop()
        throw CancellationError()
    }

    /// The page opened as the run asks and `started` told: in Safari for a debugger, LLDB's way to the page Safari
    /// opened; in another a debugger follows, how its debugger starts the browser on the page.
    private func started(_ built: BuildResult, url: String, reporter: RunReporter) async throws {
        #if os(macOS)
        if debugged?.id == SafariDebugger.browser {
            guard let lldb = ToolResolver().lldb else {
                throw ToolingError(.missingToolchain, "lldb is not here: it comes with the Swift toolchain, beside swift.")
            }
            let address = SafariDebugger.address(url, run: Int(Date().timeIntervalSince1970))
            let page = try await SafariDebugger.open(address, lldb: lldb)
            reporter.started(LaunchedApplication(
                build: built, process: nil, held: false, debugger: DebugDescriptors.safari(process: page), url: address))
            return
        }
        #endif
        let program = try debugged?.programUri.map(FileURI.url)
        let debugger = program.map { DebugDescriptors.page(url, browser: $0, site: site) }
        reporter.started(LaunchedApplication(build: built, process: nil, held: false, debugger: debugger, url: url))
        if debugger == nil, browser != "none" { await Browsers.open(url, in: browser ?? "default") }
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
