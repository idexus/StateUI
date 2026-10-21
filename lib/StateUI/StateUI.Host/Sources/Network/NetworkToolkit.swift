// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a host's toolkit does for the requests the application sends (`HostActs.network`), handed to its
/// `HostActPerformer` beside its `ActToolkit`: the platform's own networking, its certificates, proxy and cookies.
/// Design: docs/design/core/acts.md#requests
@_spi(Host) @MainActor public protocol NetworkToolkit: AnyObject {
    /// Whether an address with no scheme stands on a page the platform reads it against.
    var readsRelativeAddresses: Bool { get }

    /// Sends `request` and calls `answered` on the UI thread with what the server said - whatever its status - or
    /// why no answer came.
    func send(_ request: HostRequest, answered: @escaping (Result<HostResponse, ActFailure>) -> Void)
}

extension NetworkToolkit {
    /// An address is read against no page: every host's but the Web's.
    public var readsRelativeAddresses: Bool { false }
}

/// A request as the application sent it (`ApplicationContract.sendRequest`): where, how, its headers in the order
/// it named them and its body.
@_spi(Host) public struct HostRequest: Equatable, Sendable {
    /// Where the request goes.
    public let address: String

    /// The method's name, in capitals.
    public let method: String

    /// The headers, names and values, sorted by name.
    public let headers: [HostHeader]

    /// What the request carries.
    public let body: [UInt8]

    /// The request `call` sends; nil where it names none.
    public init?(_ call: HostActCall) {
        guard let address = call.arguments.value(0)?.string, !address.isEmpty else { return nil }
        let said = call.arguments.value(1)?.name ?? "GET"
        let pairs = call.arguments.value(2)?.strings ?? []
        self.address = address
        method = said.uppercased()
        headers = stride(from: 0, to: pairs.count - 1, by: 2).map { HostHeader(name: pairs[$0], value: pairs[$0 + 1]) }
        body = call.arguments.value(3)?.bytes ?? []
    }

    /// A request made in code - what a test sends.
    public init(address: String, method: String = "GET", headers: [HostHeader] = [], body: [UInt8] = []) {
        self.address = address
        self.method = method.uppercased()
        self.headers = headers
        self.body = body
    }

    /// Whether the address names its scheme - `https:`, `http:` - before anything else.
    public var namesItsScheme: Bool {
        guard let colon = address.firstIndex(of: ":"), colon != address.startIndex else { return false }
        return address[..<colon].allSatisfy { $0.isLetter || $0.isNumber || "+-.".contains($0) }
            && address.first?.isLetter == true
    }
}

/// One header: its name and its value.
@_spi(Host) public struct HostHeader: Equatable, Sendable {
    /// The header's name, in the case it was given.
    public let name: String

    /// What it says.
    public let value: String

    /// A header of `name` saying `value`.
    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

/// What a server answered, as the platform hands it over.
@_spi(Host) public struct HostResponse: Equatable, Sendable {
    /// The status.
    public let status: Int

    /// The headers as the platform gave them: any case, a name perhaps twice.
    public let headers: [HostHeader]

    /// What came back.
    public let body: [UInt8]

    /// An answer of `status`, with the headers and the body the platform handed over.
    public init(status: Int, headers: [HostHeader], body: [UInt8]) {
        self.status = status
        self.headers = headers
        self.body = body
    }

    /// The answer as the act carries it: the status, the headers as names and values in turn - their names in
    /// lowercase, one said twice joined with a comma, sorted by name - and the body.
    public var answer: [HostValue] {
        var joined: [String: String] = [:]
        for header in headers {
            let name = header.name.lowercased()
            joined[name] = joined[name].map { "\($0), \(header.value)" } ?? header.value
        }
        let said = joined.sorted { $0.key < $1.key }.flatMap { [$0.key, $0.value] }
        return [.number(Double(status)), .strings(said), .bytes(body)]
    }
}
