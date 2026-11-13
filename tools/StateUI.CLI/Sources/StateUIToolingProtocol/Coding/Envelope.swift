// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A one-shot answer as the terminal writes it in JSON: the API version and the result.
///
///     {"apiVersion":"1.0","result":{...}}
public struct Envelope<Result: Codable & Sendable>: Codable, Sendable {
    /// The API version the result is written in.
    public var apiVersion: String
    /// The result.
    public var result: Result

    /// `result`, written in `apiVersion`.
    public init(apiVersion: String, result: Result) {
        self.apiVersion = apiVersion
        self.result = result
    }
}

extension Envelope: Equatable where Result: Equatable {}
