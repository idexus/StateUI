// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A request an application sends to a server with `ApplicationSession.send(_:)`: where, how, with which headers and
/// what body.
///
///     let asked = HTTPRequest(
///         "https://example.com/api/parcels", method: .post,
///         headers: ["Content-Type": "application/json"], body: Array(#"{"id": 42}"#.utf8))
public struct HTTPRequest: Hashable, Sendable {
    /// Where the request goes, its scheme included - on the Web an address with none stands on the page's own.
    public var address: String

    /// What the request asks of what the address names.
    public var method: HTTPMethod

    /// The request's headers, by name.
    public var headers: [String: String]

    /// What the request carries: none for a request that sends nothing.
    public var body: [UInt8]

    /// A request to `address`, asked with `method`, carrying `headers` and `body`.
    ///
    /// - Parameters:
    ///   - address: where the request goes, its scheme included.
    ///   - method: what it asks; `.get` where nothing is said.
    ///   - headers: its headers, by name.
    ///   - body: what it carries.
    public init(_ address: String, method: HTTPMethod = .get, headers: [String: String] = [:], body: [UInt8] = []) {
        self.address = address
        self.method = method
        self.headers = headers
        self.body = body
    }
}

/// What a request asks of the resource it names, by the name HTTP gives it.
public struct HTTPMethod: Hashable, Sendable {
    /// The method's name as HTTP spells it: `GET`, `POST`.
    public let name: String

    /// The method of `name`, in capitals.
    ///
    /// - Parameter name: the method's name.
    public init(_ name: String) {
        self.name = name.uppercased()
    }

    /// Reads what the address names.
    public static let get = HTTPMethod("GET")

    /// Sends the body to what the address names.
    public static let post = HTTPMethod("POST")

    /// Puts the body in place of what the address names.
    public static let put = HTTPMethod("PUT")

    /// Changes part of what the address names.
    public static let patch = HTTPMethod("PATCH")

    /// Removes what the address names.
    public static let delete = HTTPMethod("DELETE")

    /// Reads only the headers of what the address names.
    public static let head = HTTPMethod("HEAD")
}
