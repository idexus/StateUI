// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// The SVG renderer every picture is drawn with, on every machine: `resvg` of the pinned release, which the machine
/// installs - `STATEUI_RESVG` names it, else the search path finds it. Found, never shipped.
/// Design: docs/design/tooling/pictures.md#the-renderer
struct Resvg: Sendable {
    /// The release every machine draws with, so a picture is the same pixels wherever it is drawn.
    static let release = "0.50.0"

    /// How a machine gets it.
    static let advice = "Install resvg \(release): `brew install resvg` on a Mac, `cargo install resvg --version \(release)` anywhere, or its release archive from https://github.com/linebender/resvg/releases - STATEUI_RESVG names one off the search path."

    let program: URL

    /// The renderer `environment` names or its search path finds, at the pinned release.
    ///
    /// - Throws: ``ToolingError`` `MISSING_TOOLCHAIN` where there is none, or another release.
    static func find(environment: [String: String] = ProcessInfo.processInfo.environment) async throws -> Resvg {
        let named = environment["STATEUI_RESVG"].flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0) }
        guard let program = named ?? SearchPath(environment: environment).find("resvg") else {
            throw ToolingError(.missingToolchain, "No resvg draws the pictures. \(advice)")
        }
        let said = await ToolOutput.text(.path(program.path), ["--version"]) ?? ""
        guard said.trimmingCharacters(in: .whitespacesAndNewlines) == release else {
            throw ToolingError(.missingToolchain, "\(program.path) is resvg \(said.trimmingCharacters(in: .whitespacesAndNewlines)), not \(release). \(advice)")
        }
        return Resvg(program: program)
    }

    /// Draws `svg` into `png`, `zoom` times its own size where given.
    func draw(_ svg: URL, to png: URL, zoom: Double? = nil) async throws {
        let arguments = zoom.map { ["--zoom", "\($0)"] } ?? []
        try FileManager.default.createDirectory(at: png.deletingLastPathComponent(), withIntermediateDirectories: true)
        try await ToolStep.run(.path(program.path), arguments + [svg.path, png.path], limit: .seconds(120))
    }
}
