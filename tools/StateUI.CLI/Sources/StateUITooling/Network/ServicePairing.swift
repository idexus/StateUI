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
    /// The identity of the machine it serves (`MachineIdentity`), which a client checks.
    public let identity: String
    private let file: URL
    private let now: @Sendable () -> Date
    private let said: @Sendable (String) -> Void
    private let state: Mutex<State>

    /// The pairings kept in `file`, the service named `name` of identity `identity` - this machine's where none is
    /// given; each new code told to `said`.
    ///
    /// - Throws: ``ToolingError`` where this machine's identity can be neither read nor made.
    public init(
        file: URL = BuildPermit.userFolder.appendingPathComponent("service/clients.json"),
        name: String = ProcessInfo.processInfo.environment["COMPUTERNAME"] ?? ProcessInfo.processInfo.hostName, identity: String? = nil,
        now: @escaping @Sendable () -> Date = { Date() }, said: @escaping @Sendable (String) -> Void = { _ in }
    ) throws(ToolingError) {
        self.file = file
        self.name = name
        if let identity { self.identity = identity } else { self.identity = try MachineIdentity.current().id }
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
        return PairingResult(client: paired.id, token: paired.token, service: name, identity: identity)
    }

    /// Who a connection of the service admits: its pairing and its one challenge answered before `initialize`, then
    /// a credential answering that challenge with a paired client's token; or, proved the same way, a relay to a port a
    /// run's `lldb-server` holds now, told to `relaying`.
    public func admission(relaying: @escaping @Sendable (UInt16) -> Void = { _ in }) -> Admission {
        let challenge = Mutex<String?>(nil)
        let proves: @Sendable (Credential) -> Bool = { [self] credential in
            guard let nonce = challenge.withLock({ taken in defer { taken = nil }; return taken }),
                  let client = state.withLock({ $0.clients.first { $0.id == credential.client } }) else { return false }
            let expected = SHA256.hex(SHA256.hmac(key: Array(client.token.utf8), message: Array(nonce.utf8)))
            return Self.equal(expected, credential.answer)
        }
        return Admission(
            methods: ["service/pair", "service/challenge", "service/relay"],
            answer: { [self] method, params in
                do {
                    switch method {
                    case "service/challenge":
                        let nonce = Self.randomHex(32)
                        challenge.withLock { $0 = nonce }
                        return .result(try JSONValue(encoding: Challenge(nonce: nonce, identity: identity)))
                    case "service/relay":
                        let relay = try (params ?? .object([:])).decode(RelayRequest.self)
                        guard proves(Credential(client: relay.client, answer: relay.answer)) else {
                            return .error(.notAdmitted("This client is not paired with the service, or answered not its challenge."))
                        }
                        guard DebugPorts.holds(relay.port) else {
                            return .error(.notAdmitted("No run's lldb-server holds port \(relay.port) here."))
                        }
                        relaying(relay.port)
                        return .result(.object([:]))
                    default:
                        let request = try (params ?? .object([:])).decode(PairingRequest.self)
                        return .result(try JSONValue(encoding: try pair(request)))
                    }
                } catch let error as ToolingError {
                    return .error(.notAdmitted(error.message))
                } catch {
                    return .error(.invalidParams("\(method) takes what its message says."))
                }
            },
            admits: { credential in credential.map(proves) ?? false })
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
