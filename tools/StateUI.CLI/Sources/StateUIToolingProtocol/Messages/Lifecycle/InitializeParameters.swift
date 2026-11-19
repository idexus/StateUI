// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a client says of itself as it opens a connection: `initialize`'s parameters.
public struct InitializeParameters: Codable, Equatable, Sendable {
    /// The API versions the client speaks.
    public var apiVersions: [APIVersionRange]
    /// The client's name and release.
    public var client: ToolIdentity
    /// The workspace the client opens, as a file URI.
    public var workspaceUri: String
    /// What proves a client paired with a service: none over a program's standard streams.
    public var credential: Credential?

    /// A client speaking `apiVersions`, opening `workspaceUri`, proving itself with `credential` to a service.
    public init(apiVersions: [APIVersionRange], client: ToolIdentity, workspaceUri: String, credential: Credential? = nil) {
        self.apiVersions = apiVersions
        self.client = client
        self.workspaceUri = workspaceUri
        self.credential = credential
    }
}
