// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// An application's file, `stateui.json`, beside its `Package.swift`: what the application is on every platform -
/// its identifier, its version and its build. A folder holding one is an application.
/// Design: docs/design/tooling/projects.md#an-applications-file
public struct ApplicationFile: Codable, Equatable, Sendable {
    /// The file's name, which marks an application's folder.
    public static let name = "stateui.json"
    /// The version of the file's form this tool reads.
    public static let currentVersion = 1
    /// The largest build every platform takes: Android's largest version code.
    public static let largestBuild = 2_100_000_000

    /// The version of the file's form.
    public var schemaVersion: Int
    /// What names the application to every platform: `pl.example.notes`.
    public var identifier: String
    /// The version shown to the user: `1.0.0`.
    public var version: String
    /// The build, which grows with every release of the application: `1`.
    public var build: Int

    /// An application named `identifier`, at `version` and `build`.
    public init(identifier: String, version: String, build: Int) {
        schemaVersion = Self.currentVersion
        self.identifier = identifier
        self.version = version
        self.build = build
    }

    /// The file at `url`, read whole and checked.
    ///
    /// - Throws: ``ToolingError`` `INVALID_CONFIGURATION` naming what cannot be read and where.
    public static func read(_ url: URL) throws(ToolingError) -> ApplicationFile {
        let invalid = { (reason: String) in ToolingError(.invalidConfiguration, "\(url.path): \(reason)") }
        guard let data = try? Data(contentsOf: url) else { throw invalid("it cannot be read.") }
        guard let json = try? ToolingJSON.decoder().decode(JSONValue.self, from: data) else { throw invalid("it is not JSON.") }
        let file: ApplicationFile
        do {
            file = try json.decode(ApplicationFile.self)
        } catch let error as StrictDecodingError {
            throw invalid("it has no field \(error.unread.joined(separator: ", ")).")
        } catch {
            throw invalid("\(error)")
        }
        guard file.schemaVersion == currentVersion else {
            throw invalid("its schemaVersion \(file.schemaVersion) is not \(currentVersion), the one this tool reads.")
        }
        if let problem = file.problem { throw invalid(problem) }
        return file
    }

    /// What every platform would refuse of the file; nil where each takes it.
    /// Design: docs/design/tooling/projects.md#an-applications-file
    public var problem: String? {
        if !Self.isIdentifier(identifier) {
            return "its identifier \"\(identifier)\" is not two or more parts joined by dots, each a letter, then letters"
                + " and digits: pl.example.notes."
        }
        if !Self.isVersion(version) {
            return "its version \"\(version)\" is not one to three numbers joined by dots: 1.0.0."
        }
        if !(1...Self.largestBuild).contains(build) {
            return "its build \(build) is not a number from 1 to \(Self.largestBuild)."
        }
        return nil
    }

    /// Whether `identifier` is one every platform takes: two or more parts joined by dots, each an ASCII letter, then
    /// ASCII letters and digits.
    static func isIdentifier(_ identifier: String) -> Bool {
        let parts = identifier.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count >= 2 && parts.allSatisfy { part in
            guard let first = part.unicodeScalars.first, first.isASCIILetter else { return false }
            return part.unicodeScalars.allSatisfy { $0.isASCIILetter || ("0"..."9").contains($0) }
        }
    }

    /// Whether `version` is one to three numbers joined by dots, none with a leading zero but a zero itself.
    static func isVersion(_ version: String) -> Bool {
        let parts = version.split(separator: ".", omittingEmptySubsequences: false)
        return (1...3).contains(parts.count) && parts.allSatisfy { part in
            !part.isEmpty && part.count <= 9 && part.unicodeScalars.allSatisfy { ("0"..."9").contains($0) }
                && (part == "0" || part.first != "0")
        }
    }

    /// Writes the file: its keys in sorted order, a line break at its end - the same file every time.
    public func write(to url: URL) throws {
        try (ToolingJSON.encoder(pretty: true).encode(self) + Data("\n".utf8)).write(to: url)
    }
}

private extension Unicode.Scalar {
    var isASCIILetter: Bool { ("a"..."z").contains(self) || ("A"..."Z").contains(self) }
}
