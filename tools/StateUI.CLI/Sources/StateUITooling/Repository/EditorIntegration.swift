// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// A checkout's editor extension packaged from its sources - `editors/VSCode` by its own `npm run package`, into
/// `artifacts/<name>-<version>.vsix` - and installed over itself by the editor's command line, then found among the
/// editor's extensions at its version.
/// Design: docs/design/tooling/repository.md#an-editors-extension
struct EditorIntegration: Sendable {
    let checkout: URL

    /// Where `editor`'s extension's sources stand in the checkout.
    func sources(of editor: Editor) -> URL {
        switch editor {
        case .vscode: checkout.appendingPathComponent("editors/VSCode")
        }
    }

    /// Packages `editor`'s extension, its dependencies installed first where none are.
    ///
    /// - Throws: ``ToolingError`` `PROJECT_NOT_FOUND` where the checkout holds no sources of it, `TOOL_FAILED` where
    ///   npm failed or wrote no package.
    func package(_ editor: Editor, reporter: BuildReporter) async throws -> EditorExtension {
        let folder = sources(of: editor)
        guard let manifest = try? JSONSerialization.jsonObject(with: Data(contentsOf: folder.appendingPathComponent("package.json"))) as? [String: Any],
              let name = manifest["name"] as? String, let publisher = manifest["publisher"] as? String,
              let version = manifest["version"] as? String else {
            throw ToolingError(.projectNotFound, "No extension's package.json in \(folder.path).")
        }
        if !FileManager.default.fileExists(atPath: folder.appendingPathComponent("node_modules").path) {
            reporter.progress("installing the extension's dependencies")
            try await npm(["ci"], in: folder, reporter: reporter)
        }
        reporter.progress("packaging \(publisher).\(name) \(version)")
        try await npm(["run", "package"], in: folder, reporter: reporter)
        let artifact = checkout.appendingPathComponent("artifacts/\(name)-\(version).vsix")
        guard FileManager.default.fileExists(atPath: artifact.path) else {
            throw ToolingError(.toolFailed, "npm run package wrote no \(artifact.path).")
        }
        return EditorExtension(artifactUri: FileURI.string(artifact), extensionId: "\(publisher).\(name)", version: version)
    }

    /// Installs `editorExtension` over any other version with `editor`, the editor's command line, and finds it among
    /// the editor's extensions at its version.
    ///
    /// - Throws: ``ToolingError`` `TOOL_FAILED` where the editor refused it or does not list it so.
    static func install(_ editorExtension: EditorExtension, with editor: URL, reporter: BuildReporter) async throws -> EditorExtension {
        let artifact = try FileURI.url(editorExtension.artifactUri)
        reporter.progress("installing \(editorExtension.extensionId) \(editorExtension.version)")
        try await run(.path(editor.path), ["--install-extension", artifact.path, "--force"], in: nil, reporter: reporter)
        let listed = await ToolOutput.standardOutput(.path(editor.path), ["--list-extensions", "--show-versions"], limit: .seconds(60)) ?? ""
        let installed = "\(editorExtension.extensionId)@\(editorExtension.version)".lowercased()
        guard listed.split(whereSeparator: \.isNewline).contains(where: { $0.lowercased() == installed }) else {
            throw ToolingError(.toolFailed, "\(editor.lastPathComponent) does not list \(installed) after installing it.")
        }
        return editorExtension
    }

    private func npm(_ arguments: [String], in folder: URL, reporter: BuildReporter) async throws {
        try await Self.run(.name("npm"), arguments, in: folder, reporter: reporter)
    }

    /// Runs `executable`, its output said.
    private static func run(_ executable: ProcessExecutable, _ arguments: [String], in folder: URL?, reporter: BuildReporter) async throws {
        let outcome = try await ProcessRunner().run(
            ProcessRequest(executable, arguments: arguments, workingDirectory: folder?.path), output: reporter.output)
        guard outcome.succeeded else {
            throw ToolingError(.toolFailed, "\(arguments.joined(separator: " ")) failed: its output says why.")
        }
    }
}
