// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An editor a checkout makes an extension for.
public enum Editor: String, Codable, Sendable, CaseIterable {
    /// Visual Studio Code: `editors/VSCode`.
    case vscode
}

/// The editor whose extension a checkout packages: `repository/integrationPackage`'s parameters.
public struct IntegrationPackageRequest: Codable, Equatable, Sendable {
    public var editor: Editor

    /// `editor`'s extension.
    public init(editor: Editor) {
        self.editor = editor
    }
}

/// An editor's extension, packaged: its file, as a file URI, and what the editor knows it by.
public struct EditorExtension: Codable, Equatable, Sendable {
    public var artifactUri: String
    /// `<publisher>.<name>`: `idexus.stateui`.
    public var extensionId: String
    public var version: String

    /// Extension `extensionId` at `version`, packaged in `artifactUri`.
    public init(artifactUri: String, extensionId: String, version: String) {
        self.artifactUri = artifactUri
        self.extensionId = extensionId
        self.version = version
    }
}

/// A packaged extension installed by an editor's own command line: `repository/integrationInstall`'s parameters.
public struct IntegrationInstallRequest: Codable, Equatable, Sendable {
    public var editorExtension: EditorExtension
    /// The editor's command line, as a file URI: VS Code's `code`.
    public var editorExecutableUri: String

    /// `editorExtension` installed by `editorExecutableUri`.
    public init(editorExtension: EditorExtension, editorExecutableUri: String) {
        self.editorExtension = editorExtension
        self.editorExecutableUri = editorExecutableUri
    }
}
