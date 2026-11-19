// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import ArgumentParser
import Foundation
import StateUITooling
import StateUIToolingProtocol

/// How a command writes its result on standard output.
enum OutputFormat: String, CaseIterable, ExpressibleByArgument {
    /// Words for a person.
    case text
    /// One JSON document, the result in its envelope.
    case json
    /// The result in its envelope on one line - a document a line, to be appended to a log of them.
    case jsonl

    /// Writes `result` - in JSON its envelope alone, so standard output holds nothing else.
    func write<Result: Codable & Sendable>(_ result: Result, text: (Result) -> String) throws {
        let line: String
        switch self {
        case .text:
            line = text(result)
        case .json, .jsonl:
            let envelope = Envelope(apiVersion: Release.newestAPIVersion, result: result)
            let data = try ToolingJSON.encoder(pretty: self == .json).encode(envelope)
            line = String(decoding: data, as: UTF8.self)
        }
        FileHandle.standardOutput.write(Data((line + "\n").utf8))
    }

    /// Writes `error`: in JSON its envelope on standard output, in words on standard error.
    func write(_ error: ToolingError) throws {
        guard self != .text else { return StandardOutput.diagnose("stateui: \(error.message)") }
        let envelope = ErrorEnvelope(apiVersion: Release.newestAPIVersion, error: error)
        let data = try ToolingJSON.encoder(pretty: self == .json).encode(envelope)
        FileHandle.standardOutput.write(data + Data("\n".utf8))
    }
}
