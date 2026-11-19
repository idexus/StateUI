// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// A JSON file of the tool's: its form's version, and what of it the tool checks beyond its fields.
public protocol ToolFile: Codable, Sendable {
    /// The version of the file's form this tool reads.
    static var currentVersion: Int { get }
    /// The version of the file's form.
    var schemaVersion: Int { get }
    /// What the tool refuses of the file beyond its fields; nil where it takes it.
    var problem: String? { get }
}

extension ToolFile {
    public var problem: String? { nil }

    /// The file at `url`, read whole and checked: a field it does not read, another `schemaVersion` or a problem is
    /// refused by what and where.
    ///
    /// - Throws: ``ToolingError`` `INVALID_CONFIGURATION` naming what cannot be read and where.
    public static func read(_ url: URL) throws(ToolingError) -> Self {
        let invalid = { (reason: String) in ToolingError(.invalidConfiguration, "\(url.path): \(reason)") }
        guard let data = try? Data(contentsOf: url) else { throw invalid("it cannot be read.") }
        guard let json = try? ToolingJSON.decoder().decode(JSONValue.self, from: data) else { throw invalid("it is not JSON.") }
        let file: Self
        do {
            file = try json.decode(Self.self)
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

    /// Writes the file: its keys in sorted order, a line break at its end - the same file every time - its folder
    /// made where none stands.
    public func write(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try (ToolingJSON.encoder(pretty: true).encode(self) + Data("\n".utf8)).write(to: url)
    }
}
