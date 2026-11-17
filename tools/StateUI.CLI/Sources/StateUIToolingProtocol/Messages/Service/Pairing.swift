// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A client asking a service to pair with it - `service/pair`, before `initialize`: the code the service showed, and
/// the client's name for the service to keep.
public struct PairingRequest: Codable, Equatable, Sendable {
    public var code: String
    public var client: String

    /// Pairing as `client` with the code `code`.
    public init(code: String, client: String) {
        self.code = code
        self.client = client
    }
}

/// A pairing made: the client's id and token, which it proves itself with ever after, and the service's name.
public struct PairingResult: Codable, Equatable, Sendable {
    public var client: String
    public var token: String
    public var service: String

    /// Client `client`, its token `token`, paired with the service `service`.
    public init(client: String, token: String, service: String) {
        self.client = client
        self.token = token
        self.service = service
    }
}

/// A service's challenge to a connection - `service/challenge`, before `initialize`: once, for that connection.
public struct Challenge: Codable, Equatable, Sendable {
    public var nonce: String

    /// The challenge `nonce`.
    public init(nonce: String) {
        self.nonce = nonce
    }
}

/// What proves a paired client to a service: its id, and its answer to the connection's challenge - the token's
/// HMAC-SHA256 of the nonce, the token itself never sent.
public struct Credential: Codable, Equatable, Sendable {
    public var client: String
    public var answer: String

    /// Client `client`, answering `answer`.
    public init(client: String, answer: String) {
        self.client = client
        self.answer = answer
    }
}
