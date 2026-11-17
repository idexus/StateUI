// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol
import Synchronization

/// The clients a service admits, kept on its machine, and the code a new one pairs with: shown by the service, good
/// for ten minutes and one pairing, retired after five wrong tries. Each connection is challenged once, and a client
/// proves its token by the HMAC of that challenge - the token itself never crosses the network.
/// Design: docs/design/tooling/service.md#pairing
public final class ServicePairing: Sendable {
    /// A paired client: its id, its name, the token it proves itself with.
    struct Client: Codable, Equatable, Sendable {
        var id: String
        var name: String
        var token: String
    }

    private struct State: Sendable {
        var clients: [Client]
        var code: String
        var issued: Date
        var wrong = 0
    }

    /// The service's own name, which a paired client keeps.
    public let name: String
    private let file: URL
    private let now: @Sendable () -> Date
    private let said: @Sendable (String) -> Void
    private let state: Mutex<State>

    /// The pairings kept in `file`, the service named `name`; each new code told to `said`.
    public init(
        file: URL = BuildPermit.userFolder.appendingPathComponent("service/clients.json"),
        name: String = ProcessInfo.processInfo.environment["COMPUTERNAME"] ?? ProcessInfo.processInfo.hostName, now: @escaping @Sendable () -> Date = { Date() },
        said: @escaping @Sendable (String) -> Void = { _ in }
    ) {
        self.file = file
        self.name = name
        self.now = now
        self.said = said
        let kept = (try? JSONDecoder().decode([Client].self, from: Data(contentsOf: file))) ?? []
        state = Mutex(State(clients: kept, code: Self.newCode(), issued: now()))
        said(state.withLock { $0.code })
    }

    /// The code a client pairs with now.
    public var code: String { state.withLock { $0.code } }

    /// When the code shown now stops pairing.
    public var codeUntil: Date { state.withLock { $0.issued.addingTimeInterval(600) } }

    /// Pairs the client `request` names where its code is the service's and still good: its id and token, kept here.
    func pair(_ request: PairingRequest) throws(ToolingError) -> PairingResult {
        let (paired, renewed): (Client?, Bool) = state.withLock { state in
            guard now().timeIntervalSince(state.issued) < 600, Self.equal(request.code, state.code) else {
                state.wrong += 1
                guard state.wrong >= 5 || now().timeIntervalSince(state.issued) >= 600 else { return (nil, false) }
                Self.renew(&state, at: now())
                return (nil, true)
            }
            let client = Client(id: UUID().uuidString.lowercased(), name: request.client, token: Self.randomHex(32))
            state.clients.append(client)
            Self.renew(&state, at: now())
            return (client, true)
        }
        if renewed { said(code) }
        guard let paired else {
            throw ToolingError(.invalidConfiguration, "\(request.code) is not the pairing code the service shows now.")
        }
        try save()
        return PairingResult(client: paired.id, token: paired.token, service: name)
    }

    /// Who a connection of the service admits: its pairing and its one challenge answered before `initialize`, then
    /// a credential answering that challenge with a paired client's token.
    public func admission() -> Admission {
        let challenge = Mutex<String?>(nil)
        return Admission(
            methods: ["service/pair", "service/challenge"],
            answer: { [self] method, params in
                do {
                    if method == "service/challenge" {
                        let nonce = Self.randomHex(32)
                        challenge.withLock { $0 = nonce }
                        return .result(try JSONValue(encoding: Challenge(nonce: nonce)))
                    }
                    let request = try (params ?? .object([:])).decode(PairingRequest.self)
                    return .result(try JSONValue(encoding: try pair(request)))
                } catch let error as ToolingError {
                    return .error(.notAdmitted(error.message))
                } catch {
                    return .error(.invalidParams("\(method) takes a code and a client's name."))
                }
            },
            admits: { [self] credential in
                guard let credential, let nonce = challenge.withLock({ taken in defer { taken = nil }; return taken }),
                      let client = state.withLock({ $0.clients.first { $0.id == credential.client } }) else { return false }
                let expected = SHA256.hex(SHA256.hmac(key: Array(client.token.utf8), message: Array(nonce.utf8)))
                return Self.equal(expected, credential.answer)
            })
    }

    /// Writes the clients, readable by this machine's user alone.
    private func save() throws(ToolingError) {
        let clients = state.withLock { $0.clients }
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(clients).write(to: file, options: .atomic)
            #if !os(Windows)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
            #endif
        } catch {
            throw ToolingError(.toolFailed, "The service's clients were not written to \(file.path): \(error).")
        }
    }

    private static func renew(_ state: inout State, at time: Date) {
        (state.code, state.issued, state.wrong) = (newCode(), time, 0)
    }

    private static func newCode() -> String {
        let number = Int.random(in: 0..<1_000_000)
        return String(repeating: "0", count: 6 - String(number).count) + String(number)
    }

    /// `count` bytes of the system's secure randomness, as hexadecimal.
    static func randomHex(_ count: Int) -> String {
        var generator = SystemRandomNumberGenerator()
        return SHA256.hex((0..<count).map { _ in UInt8.random(in: 0...255, using: &generator) })
    }

    /// Whether `a` and `b` are the same, compared in a time their likeness does not tell.
    static func equal(_ a: String, _ b: String) -> Bool {
        let (left, right) = (Array(a.utf8), Array(b.utf8))
        guard left.count == right.count else { return false }
        return zip(left, right).reduce(0) { $0 | ($1.0 ^ $1.1) } == 0
    }
}
