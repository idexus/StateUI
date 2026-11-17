// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How a debugger reaches an application, as the tool readied it: LLDB starting its program or attaching to its
/// process, with the commands that ready the way, or a browser's debugger started on its page - what every editor
/// maps to its own debugger, none deciding the way itself.
public struct DebugDescriptor: Codable, Equatable, Sendable {
    /// Which debugger: LLDB, for Swift; a browser's, for a page.
    public enum Kind: String, Codable, Sendable {
        case lldb
        case browser
    }

    /// Whether the debugger starts the application or attaches to it running.
    public enum Request: String, Codable, Sendable {
        case launch
        case attach
    }

    public var kind: Kind
    public var request: Request
    /// A launch's program, as a file URI: LLDB's the application's, a browser's the browser's.
    public var programUri: String?
    /// The folder an LLDB launch starts its program in, as a file URI.
    public var workingUri: String?
    /// An attach's process.
    public var process: Int?
    /// LLDB's commands before its target is made: the platform, its connection, where symbols stand.
    public var initCommands: [String]
    /// LLDB's commands that attach, where an attach to `process` alone does not reach it.
    public var attachCommands: [String]
    /// LLDB's commands that end the application with the session.
    public var terminateCommands: [String]
    /// A browser's page.
    public var url: String?
    /// The folder a page's files stand in, as a file URI: where a browser's debugger reads its sources.
    public var sourceUri: String?

    /// A debugger reaching an application as `kind` and `request` say.
    public init(
        kind: Kind, request: Request, programUri: String? = nil, workingUri: String? = nil, process: Int? = nil,
        initCommands: [String] = [], attachCommands: [String] = [], terminateCommands: [String] = [], url: String? = nil,
        sourceUri: String? = nil
    ) {
        self.kind = kind
        self.request = request
        self.programUri = programUri
        self.workingUri = workingUri
        self.process = process
        self.initCommands = initCommands
        self.attachCommands = attachCommands
        self.terminateCommands = terminateCommands
        self.url = url
        self.sourceUri = sourceUri
    }
}
