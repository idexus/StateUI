// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// One client's connection: its frames read, its life kept, its requests answered.
/// Design: docs/design/tooling/protocol.md#a-connections-life
public actor Connection {
    /// Where a connection stands in its life.
    public enum State: Sendable, Equatable {
        /// Waiting for `initialize`.
        case created
        /// Initialized, waiting for `initialized`.
        case initializing
        /// Answering the service's methods.
        case ready
        /// Shut down, waiting for `exit`.
        case shuttingDown
        /// Ended.
        case closed
    }

    /// Where the connection stands.
    public private(set) var state = State.created
    /// Whether the client shut the service down before the connection ended - the clean end.
    public private(set) var shutDown = false

    private enum Answer: Sendable {
        case now(OutgoingMessage)
        case later(id: RequestID, method: String, params: JSONValue?)
        case afterPending(OutgoingMessage)
    }

    private var reader = FrameReader()
    private let server: ToolIdentity
    private let apiVersions: [APIVersionRange]
    private let methods: Methods
    private let send: @Sendable (Data) -> Void
    private let diagnose: @Sendable (String) -> Void
    private let instance = UUID().uuidString.lowercased()
    private var pending: [Int: Task<Void, Never>] = [:]
    private var nextPending = 0

    /// A connection of the service `server`, speaking `apiVersions` and answering `methods`, which writes each
    /// frame through `send` and each diagnostic - never a frame - through `diagnose`.
    public init(
        server: ToolIdentity,
        apiVersions: [APIVersionRange],
        methods: Methods,
        send: @escaping @Sendable (Data) -> Void,
        diagnose: @escaping @Sendable (String) -> Void
    ) {
        self.server = server
        self.apiVersions = apiVersions
        self.methods = methods
        self.send = send
        self.diagnose = diagnose
    }

    /// Reads `bytes` as they came; `false` once the connection has ended.
    public func receive(_ bytes: Data) -> Bool {
        guard state != .closed else { return false }
        let bodies: [Data]
        do {
            bodies = try reader.take(bytes)
        } catch {
            diagnose("stateui: the connection ends on bytes that are no frame: \(error)")
            state = .closed
            return false
        }
        for body in bodies where state != .closed {
            switch IncomingBody(body) {
            case .unreadable(let error): write(.response(id: .null, outcome: .error(error)))
            case .single(let message): dispatch([message], batch: false)
            case .batch(let messages): dispatch(messages, batch: true)
            }
        }
        return state != .closed
    }

    /// The client's end of the connection closed; returns once every request accepted is answered.
    public func end() async {
        state = .closed
        await settle()
    }

    private func dispatch(_ messages: [IncomingMessage], batch: Bool) {
        let answers = messages.compactMap(answer)
        let ready = answers.compactMap { answer -> OutgoingMessage? in
            if case .now(let message) = answer { message } else { nil }
        }
        if ready.count == answers.count {
            if batch, !ready.isEmpty { write(.batch(ready)) } else { ready.forEach(write) }
            return
        }
        let (methods, send, diagnose, earlier) = (methods, send, diagnose, Array(pending.values))
        let key = nextPending
        nextPending += 1
        pending[key] = Task {
            var written: [OutgoingMessage] = []
            for answer in answers {
                switch answer {
                case .now(let message):
                    written.append(message)
                case .later(let id, let method, let params):
                    written.append(.response(id: id, outcome: await methods.answer(method, params: params)))
                case .afterPending(let message):
                    for task in earlier { await task.value }
                    written.append(message)
                }
            }
            Self.write(batch ? .batch(written) : written[0], send, diagnose)
            answered(key)
        }
    }

    /// Returns once every request accepted so far is answered.
    func settle() async {
        while let task = pending.values.first {
            await task.value
        }
    }

    private func answered(_ key: Int) {
        pending[key] = nil
    }

    private func answer(_ message: IncomingMessage) -> Answer? {
        switch message {
        case .invalid(let id, let error):
            return .now(.response(id: id ?? .null, outcome: .error(error)))
        case .response(let id):
            diagnose("stateui: an answer to no request of the service's: \(id)")
            return nil
        case .notification(let method, _):
            notify(method)
            return nil
        case .request(let id, let method, let params):
            return request(id, method, params)
        }
    }

    private func notify(_ method: String) {
        switch method {
        case "initialized" where state == .initializing:
            state = .ready
        case "exit":
            state = .closed
        case "initialized", "initialize", "shutdown":
            diagnose("stateui: \(method) came as a notification while the connection is \(state); it was passed over")
        default:
            if methods.contains(method) {
                diagnose("stateui: \(method) came as a notification; a method is called with an id, so it did not run")
            }
        }
    }

    private func request(_ id: RequestID, _ method: String, _ params: JSONValue?) -> Answer {
        let outcome: OutgoingMessage.Outcome
        switch (method, state) {
        case ("initialize", _):
            outcome = initialize(params ?? .object([:]))
        case ("initialized", _), ("exit", _):
            outcome = .error(.invalidRequest("\(method) is a notification."))
        case ("shutdown", .initializing), ("shutdown", .ready):
            state = .shuttingDown
            shutDown = true
            return .afterPending(.response(id: id, outcome: .result(.null)))
        case (_, .created), (_, .initializing):
            outcome = .error(.notInitialized)
        case (_, .shuttingDown), (_, .closed):
            outcome = .error(.shuttingDown)
        case (_, .ready):
            guard methods.contains(method) else { return .now(.response(id: id, outcome: .error(.methodNotFound(method)))) }
            return .later(id: id, method: method, params: params)
        }
        return .now(.response(id: id, outcome: outcome))
    }

    private func initialize(_ params: JSONValue) -> OutgoingMessage.Outcome {
        guard state == .created else { return .error(.invalidRequest("The connection is initialized already.")) }
        let parameters: InitializeParameters
        switch Methods.read(InitializeParameters.self, of: "initialize", from: params) {
        case .success(let read): parameters = read
        case .failure(let error): return .error(error)
        }
        guard let version = APIVersionRange.newestShared(parameters.apiVersions, apiVersions) else {
            let spoken = apiVersions.map { "\($0.major).\($0.minMinor)-\($0.major).\($0.maxMinor)" }
            return .error(.incompatibleAPI("The tool speaks API \(spoken.joined(separator: ", ")) only."))
        }
        let result = InitializeResult(
            apiVersion: version,
            serverInstanceId: instance,
            server: server,
            workspace: Workspace(uri: parameters.workspaceUri),
            capabilities: ServerCapabilities(methods: methods.names, notifications: []),
            limits: .current
        )
        guard let encoded = try? JSONValue(encoding: result) else { return .error(.internalError("initialize")) }
        state = .initializing
        return .result(encoded)
    }

    private func write(_ message: OutgoingMessage) {
        Self.write(message, send, diagnose)
    }

    private static func write(
        _ message: OutgoingMessage, _ send: @Sendable (Data) -> Void, _ diagnose: @Sendable (String) -> Void
    ) {
        do {
            send(try Frame.encode(message))
        } catch {
            diagnose("stateui: a message could not be written: \(error)")
        }
    }
}
