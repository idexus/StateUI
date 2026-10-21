// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a server answered a request: its status, its headers and its body. Any status is an answer - a 404 included.
///
///     let response = try await application.send(HTTPRequest("https://example.com/api/parcels/42"))
///     if response.status == 200 { show(response.text) }
public struct HTTPResponse: Hashable, Sendable {
    /// The status the server answered: 200 for what was asked, 404 for nothing there.
    public let status: Int

    /// The answer's headers, their names in lowercase; a header said twice holds both values, a comma apart.
    public let headers: [String: String]

    /// What the server sent back.
    public let body: [UInt8]

    /// An answer of `status`, with `headers` and `body` - what a test stands in for a server with.
    ///
    /// - Parameters:
    ///   - status: the status.
    ///   - headers: the headers, by name in any case.
    ///   - body: what was sent back.
    public init(status: Int, headers: [String: String] = [:], body: [UInt8] = []) {
        self.status = status
        self.headers = Dictionary(headers.map { ($0.key.lowercased(), $0.value) }) { "\($0), \($1)" }
        self.body = body
    }

    /// The body read as UTF-8 text.
    public var text: String {
        String(decoding: body, as: UTF8.self)
    }

    /// The header of `name`, whatever its case; nil where the answer has none.
    ///
    /// - Parameter name: the header's name.
    /// - Returns: its value.
    public func header(_ name: String) -> String? {
        headers[name.lowercased()]
    }
}
