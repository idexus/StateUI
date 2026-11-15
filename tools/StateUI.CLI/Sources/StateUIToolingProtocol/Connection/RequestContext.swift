// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a method knows of the connection that called it.
public struct RequestContext: Sendable {
    /// The workspace the connection opened, as a file URI.
    public var workspaceUri: String?

    /// The context of a connection that opened `workspaceUri`.
    public init(workspaceUri: String?) {
        self.workspaceUri = workspaceUri
    }
}
