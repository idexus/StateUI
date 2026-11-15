// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// StateUI's releases as a repository publishes them: listed by their tags, cloned one at a time.
/// Design: docs/design/tooling/projects.md#a-release
public struct ReleaseCatalog: Sendable {
    private let tools: ToolResolver
    private let runner = ProcessRunner()

    /// A catalog reading repositories with the Git `tools` find.
    public init(tools: ToolResolver = ToolResolver()) {
        self.tools = tools
    }

    /// The releases of `repository` from `minimum`, newest first.
    public func releases(of repository: String, from minimum: String) async throws -> [String] {
        let listing = try await git(["ls-remote", "--tags", "--refs", repository], doing: "read the releases of \(repository)")
        return Self.releases(in: listing, from: minimum)
    }

    /// Clones `release` of `repository` into `folder`, its tree alone, and checks it is a checkout the tool can make
    /// applications from.
    func clone(_ release: String, of repository: String, into folder: URL) async throws -> Checkout {
        guard release.wholeMatch(of: /\d+\.\d+\.\d+/) != nil, Versions.atLeast(release, Release.oldestUsable) else {
            throw ToolingError(
                .incompatibleLibrary, "\(release) is no release the tool can build with: \(Release.oldestUsable) or newer.")
        }
        _ = try await git(
            ["-c", "advice.detachedHead=false", "clone", "--depth", "1", "--branch", release, repository, folder.path],
            doing: "clone \(release) of \(repository)")
        guard let checkout = Checkout(at: folder) else {
            throw ToolingError(.incompatibleLibrary, "\(release) of \(repository) is no StateUI checkout.")
        }
        return checkout
    }

    /// The releases a `git ls-remote --tags --refs` listing names - tags of three numbers - from `minimum`, newest
    /// first.
    static func releases(in listing: String, from minimum: String) -> [String] {
        listing.split(whereSeparator: \.isNewline)
            .compactMap { $0.firstMatch(of: /refs\/tags\/(\d+\.\d+\.\d+)$/).map { String($0.output.1) } }
            .filter { Versions.atLeast($0, minimum) }
            .sorted { Versions.compare($0, $1) > 0 }
    }

    private func git(_ arguments: [String], doing what: String) async throws -> String {
        let output = Gathered()
        let outcome: ProcessOutcome
        do {
            outcome = try await runner.run(ProcessRequest(tools.git, arguments: arguments, timeout: .seconds(600)), output: output.add)
        } catch ProcessFailure.notFound {
            throw ToolingError(.missingToolchain, "Git cannot be found: install it to \(what).")
        }
        try Task.checkCancellation()
        guard outcome.succeeded else {
            let said = output.lines(of: .standardError).suffix(3).joined(separator: "\n")
            throw ToolingError(.toolFailed, "Git could not \(what):\n\(said)")
        }
        return output.lines(of: .standardOutput).joined(separator: "\n")
    }
}
