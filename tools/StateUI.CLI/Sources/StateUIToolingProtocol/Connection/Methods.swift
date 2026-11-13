// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The methods a service answers, each by name with its parameter and result types.
public struct Methods: Sendable {
    /// Who calls a method: the connection's instance, which owns what it starts, where its events go, and the
    /// workspace it opened.
    struct Caller: Sendable {
        var owner: String
        var channel: EventChannel
        var workspaceUri: String?
    }

    /// A method's answer, and what runs once the answer is written.
    struct Reply: Sendable {
        var outcome: OutgoingMessage.Outcome
        var then: (@Sendable () async -> Void)?
    }

    private var answers: [String: @Sendable (JSONValue, Caller) async -> Reply] = [:]

    /// The service's operations, which its mutating methods start.
    public let operations = Operations()

    /// No methods.
    public init() {}

    /// The methods' names, in sorted order.
    public var names: [String] { answers.keys.sorted() }

    /// The notifications the methods send, in sorted order.
    public var notifications: [String] { contains("operation/get") ? ["operation/event"] : [] }

    /// Whether a method of that name is answered.
    public func contains(_ name: String) -> Bool { answers[name] != nil }

    /// Adds a method answered at once: its parameters read whole as `Parameters`, its result written as `Result`.
    ///
    /// `answer` refuses a request by throwing a ``ToolingError``; any other error answers it as the service's
    /// failure.
    public mutating func query<Parameters: Codable & Sendable, Result: Codable & Sendable>(
        _ name: String,
        _ answer: @escaping @Sendable (Parameters) async throws -> Result
    ) {
        query(name) { (parameters: Parameters, _: RequestContext) in try await answer(parameters) }
    }

    /// Adds a method answered at once that reads the workspace its connection opened beside its parameters.
    public mutating func query<Parameters: Codable & Sendable, Result: Codable & Sendable>(
        _ name: String,
        _ answer: @escaping @Sendable (Parameters, RequestContext) async throws -> Result
    ) {
        answers[name] = { params, caller in
            await Self.answer(name, params, RequestContext(workspaceUri: caller.workspaceUri), answer)
        }
    }

    private static func answer<Parameters: Codable & Sendable, Result: Codable & Sendable>(
        _ name: String,
        _ params: JSONValue,
        _ context: RequestContext,
        _ answer: @escaping @Sendable (Parameters, RequestContext) async throws -> Result
    ) async -> Reply {
        let parameters: Parameters
        switch read(Parameters.self, of: name, from: params) {
        case .success(let read): parameters = read
        case .failure(let error): return Reply(outcome: .error(error))
        }
        do {
            return Reply(outcome: .result(try JSONValue(encoding: try await answer(parameters, context))))
        } catch let error as ToolingError {
            return Reply(outcome: .error(.refused(error)))
        } catch {
            return Reply(outcome: .error(.internalError("\(name) failed: \(error)")))
        }
    }

    /// Adds a method that starts an operation: it takes a `requestToken` beside `Parameters` and answers with the
    /// operation's handle at once; `work` runs once the handle is written, its result the operation's.
    ///
    /// The first such method adds `operation/get` and `operation/cancel`.
    public mutating func mutation<Parameters: Codable & Sendable, Result: Codable & Sendable>(
        _ name: String,
        _ work: @escaping @Sendable (Parameters, OperationContext) async throws -> Result
    ) {
        addOperationMethods()
        let operations = operations
        answers[name] = { params, caller in await Self.accept(name, params, caller, operations, work) }
    }

    private static func accept<Parameters: Codable & Sendable, Result: Codable & Sendable>(
        _ name: String,
        _ params: JSONValue,
        _ caller: Caller,
        _ operations: Operations,
        _ work: @escaping @Sendable (Parameters, OperationContext) async throws -> Result
    ) async -> Reply {
        guard case .object(var fields) = params, case .string(let token)? = fields.removeValue(forKey: "requestToken"),
              !token.isEmpty
        else { return Reply(outcome: .error(.invalidParams("\(name) takes a requestToken."))) }
        let parameters: Parameters
        switch read(Parameters.self, of: name, from: .object(fields)) {
        case .success(let read): parameters = read
        case .failure(let error): return Reply(outcome: .error(error))
        }
        let operationWork: Operations.Work = { context in try JSONValue(encoding: try await work(parameters, context)) }
        let request = JSONValue.object(["method": .string(name), "params": .object(fields)])
        do {
            let (handle, isNew) = try await operations.accept(
                kind: name, token: token, request: request, owner: caller.owner, channel: caller.channel, work: operationWork)
            let id = handle.operationId
            var start: (@Sendable () async -> Void)?
            if isNew { start = { @Sendable in await operations.start(id) } }
            return Reply(outcome: .result(try JSONValue(encoding: handle)), then: start)
        } catch let error as ToolingError {
            return Reply(outcome: .error(.refused(error)))
        } catch {
            return Reply(outcome: .error(.internalError("\(name) failed: \(error)")))
        }
    }

    private mutating func addOperationMethods() {
        guard !contains("operation/get") else { return }
        let operations = operations
        query("operation/get") { (reference: OperationReference) in try await operations.snapshot(reference.operationId) }
        query("operation/cancel") { (reference: OperationReference) in try await operations.cancel(reference.operationId) }
    }

    /// `params` read whole as method `name`'s `Parameters`, or the error refusing them.
    static func read<Parameters: Codable>(
        _ type: Parameters.Type, of name: String, from params: JSONValue
    ) -> Result<Parameters, RPCError> {
        do {
            return .success(try params.decode(type))
        } catch let error as StrictDecodingError {
            return .failure(.invalidParams("\(name) takes no \(error.unread.joined(separator: ", "))."))
        } catch {
            return .failure(.invalidParams("\(name) cannot read its parameters: \(error)"))
        }
    }

    /// The answer to `name` called by `caller` with `params`; parameters not sent are read as `{}`.
    func answer(_ name: String, params: JSONValue?, caller: Caller) async -> Reply {
        guard let answer = answers[name] else { return Reply(outcome: .error(.methodNotFound(name))) }
        return await answer(params ?? .object([:]), caller)
    }
}
