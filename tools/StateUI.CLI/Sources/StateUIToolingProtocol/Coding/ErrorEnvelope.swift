// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A one-shot failure as the terminal writes it in JSON: the API version and the error.
///
///     {"apiVersion":"1.0","error":{"code":"PROJECT_NOT_FOUND",...}}
public struct ErrorEnvelope: Codable, Equatable, Sendable {
    /// The API version the error is written in.
    public var apiVersion: String
    /// The error.
    public var error: ToolingError

    /// `error`, written in `apiVersion`.
    public init(apiVersion: String, error: ToolingError) {
        self.apiVersion = apiVersion
        self.error = error
    }
}
