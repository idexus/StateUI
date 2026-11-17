// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol
import Subprocess
import Synchronization
#if canImport(System)
import System
#else
import SystemPackage
#endif

/// Another stateui, asked in the protocol an editor speaks, one connection a call: served over the standard input and
/// output of the program that reaches it - a guest's `stateui serve --stdio` through `prlctl exec` - or by its
/// service, over TCP.
/// Design: docs/design/tooling/guests.md#the-guests-own-tool
public struct ServedTool: Sendable {
    /// How the served tool is reached.
    enum Road: Sendable {
        /// The program that serves it over its standard streams.
        case program(ProcessExecutable, [String])
        /// Its service, at an address and a port, the machine's pairing proved where one is kept.
        case service(String, UInt16, RemoteMachine?)
    }

    let road: Road
    let workspaceUri: String

    /// The stateui `executable` serves when run with `arguments`, its workspace `workspaceUri` as the served tool
    /// names it.
    public init(executable: ProcessExecutable, arguments: [String], workspaceUri: String) {
        road = .program(executable, arguments)
        self.workspaceUri = workspaceUri
    }

    /// The stateui whose service listens on `address` at `port`, its workspace `workspaceUri` as it names it.
    public init(address: String, port: UInt16, workspaceUri: String) {
        road = .service(address, port, nil)
        self.workspaceUri = workspaceUri
    }

    /// The stateui of the paired machine `remote`, its workspace `workspaceUri` as it names it.
    public init(remote: RemoteMachine, workspaceUri: String) {
        road = .service(remote.address, remote.port, remote)
        self.workspaceUri = workspaceUri
    }

    /// The answer to `method`, asked before the connection opens - a service's pairing.
    func beforeOpening(_ method: String, _ params: JSONValue) async throws -> JSONValue {
        try await converseByService(opening: false) { try await $0.request(method, params) }
    }

    /// What the served tool says of itself as a connection opens: the API version both speak and the methods it
    /// answers.
    public func opening() async throws -> InitializeResult {
        try await converse { try $0.opened() }
    }

    /// The result of the query `method` asked with `params`.
    public func query(_ method: String, _ params: JSONValue) async throws -> JSONValue {
        try await converse { try await $0.request(method, params) }
    }

    /// The operation `method` asked with `params`, followed to its end: its progress and output told to `reporter`,
    /// an application it started to `started`, its result returned, its failure thrown as the served tool said it.
    /// Cancelled here, it is cancelled there, and the connection waits for its end - up to `cancelLimit` - before it
    /// closes: a served tool torn down first leaves what its operation started running.
    public func operation(
        _ method: String, _ params: JSONValue, reporter: BuildReporter,
        started: @escaping @Sendable (LaunchedApplication) -> Void = { _ in }, cancelLimit: Duration = .seconds(20)
    ) async throws -> JSONValue {
        guard case .object(var fields) = params else { throw ToolingError(.internalError, "\(method) takes an object.") }
        fields["requestToken"] = .string(UUID().uuidString.lowercased())
        let asked = JSONValue.object(fields)
        let following = Following()
        // Unstructured, so a cancel here reaches the served tool as `operation/cancel` rather than tearing it down.
        let work = Task {
            try await converse { conversation in
                let handle = try await conversation.request(method, asked).decode(OperationHandle.self)
                following.follow(conversation, handle.operationId)
                let lines = OutputLines.Streams()
                var ended: OperationState?
                for await event in conversation.events where event.operationId == handle.operationId {
                    switch event.event {
                    case .state(let state) where state.isTerminal: ended = state
                    case .progress(let progress): reporter.progress(progress.message ?? progress.stage)
                    case .output(let chunk): for line in lines.take(chunk) { reporter.output(line) }
                    case .started(let application): started(application)
                    default: break
                    }
                    if ended != nil { break }
                }
                guard let ended else { throw ToolingError(.toolFailed, "The served stateui ended before \(method) did.") }
                for line in lines.finish() { reporter.output(line) }
                let snapshot = try await conversation.request("operation/get", .object(["operationId": .string(handle.operationId)]))
                    .decode(OperationSnapshot.self)
                if let failure = snapshot.failure { throw failure }
                if ended == .cancelled { throw CancellationError() }
                return snapshot.result ?? .null
            }
        }
        return try await withTaskCancellationHandler {
            try await work.value
        } onCancel: {
            following.cancel()
            Task {
                try? await Task.sleep(for: cancelLimit)
                work.cancel()
            }
        }
    }

    /// The operation a call follows, once the served tool named it: what a cancel asks to stop.
    private final class Following: Sendable {
        private let followed = Mutex<(conversation: Conversation, operation: String)?>(nil)
        private let cancelled = Mutex(false)

        func follow(_ conversation: Conversation, _ operation: String) {
            followed.withLock { $0 = (conversation, operation) }
            if cancelled.withLock({ $0 }) { cancel() }
        }

        func cancel() {
            cancelled.withLock { $0 = true }
            guard let (conversation, operation) = followed.withLock({ $0 }) else { return }
            Task { _ = try? await conversation.request("operation/cancel", .object(["operationId": .string(operation)])) }
        }
    }

    /// Starts the served tool, opens a connection, runs `body` over it, then shuts it down. A served tool that ends
    /// before answering is said with the last lines it wrote to its standard error - a crash's own words.
    private func converse<Result: Sendable>(_ body: @Sendable (Conversation) async throws -> Result) async throws -> Result {
        guard case .program(let executable, let arguments) = road else { return try await converseByService(opening: true, body) }
        let configuration = Configuration(executable: executable.subprocess, arguments: Arguments(arguments))
        do {
            return try await Subprocess.run(configuration, input: .inputWriter, output: .sequence, error: .sequence) { execution in
                let writer = execution.standardInputWriter
                let conversation = Conversation(write: { _ = try await writer.write($0) }, finish: { try? await writer.finish() })
                async let reading: Void = conversation.read(execution.standardOutput.map { $0.withUnsafeBytes { Array($0) } })
                async let diagnostics: [String] = Self.lastLines(of: execution.standardError)
                defer { conversation.endEvents() }
                let result: Swift.Result<Result, any Error>
                do {
                    try await conversation.open(workspaceUri: workspaceUri)
                    result = .success(try await body(conversation))
                } catch {
                    result = .failure(error)
                }
                await conversation.close()
                let (_, said) = await (reading, diagnostics)
                if case .failure(let error) = result, !said.isEmpty, Self.ended(error) {
                    let words = (error as? ToolingError)?.message ?? "The served stateui failed: \(error)."
                    throw ToolingError((error as? ToolingError)?.code ?? .toolFailed, words + " It wrote:\n" + said.joined(separator: "\n"))
                }
                return try result.get()
            }.closureResult
        } catch let error as SubprocessError {
            throw ToolingError(.toolFailed, "The served stateui could not be reached: \(error.description)")
        }
    }

    /// Connects to the served tool's service, opens a connection where `opening` - its pairing proved by the HMAC of
    /// the service's challenge - runs `body` over it, then shuts it down.
    private func converseByService<Result: Sendable>(
        opening: Bool, _ body: @Sendable (Conversation) async throws -> Result
    ) async throws -> Result {
        guard case .service(let address, let port, let remote) = road else { throw ToolingError(.internalError, "No service to reach.") }
        let socket = try StreamSocket.connect(to: address, port: port)
        let writer = SocketWriter(socket)
        let conversation = Conversation(write: { writer.write(Data($0)) }, finish: { writer.flush() })
        async let reading: Void = conversation.read(socket.chunks())
        defer { conversation.endEvents() }
        let result: Swift.Result<Result, any Error>
        do {
            if opening {
                var credential: Credential?
                if let remote {
                    let nonce = try await conversation.request("service/challenge", .object([:])).decode(Challenge.self).nonce
                    let answer = SHA256.hex(SHA256.hmac(key: Array(remote.token.utf8), message: Array(nonce.utf8)))
                    credential = Credential(client: remote.client, answer: answer)
                }
                try await conversation.open(workspaceUri: workspaceUri, credential: credential)
            }
            result = .success(try await body(conversation))
        } catch {
            result = .failure(error)
        }
        await conversation.close()
        socket.close()
        await reading
        return try result.get()
    }

    /// Whether `error` says the served tool itself ended - its output closed, its input broken - rather than refused.
    private static func ended(_ error: any Error) -> Bool {
        guard let error = error as? ToolingError else { return !(error is CancellationError) }
        return error.message.hasPrefix("The served stateui ended")
    }

    /// The last lines `sequence` held when it ended, at most twenty.
    private static func lastLines(of sequence: SubprocessOutputSequence) async -> [String] {
        var lines = OutputLines()
        var kept: [String] = []
        do {
            for try await buffer in sequence {
                kept = Array((kept + lines.take(buffer.withUnsafeBytes { Array($0) })).suffix(20))
            }
        } catch {}
        return Array((kept + (lines.finish().map { [$0] } ?? [])).suffix(20))
    }
}

/// One connection to a served tool: requests matched to their answers by id, its operations' events in order.
final class Conversation: Sendable {
    private let writing: @Sendable ([UInt8]) async throws -> Void
    private let finishing: @Sendable () async -> Void
    private let state = Mutex(State())
    private let stream: AsyncStream<OperationEvent>.Continuation
    /// The events of every operation, in the order the served tool wrote them.
    let events: AsyncStream<OperationEvent>

    private struct State {
        var next = 1
        var waiting: [String: CheckedContinuation<JSONValue, any Error>] = [:]
        var closed = false
        var opening: InitializeResult?
    }

    /// A connection that writes its frames through `write` and ends its output through `finish`.
    init(write: @escaping @Sendable ([UInt8]) async throws -> Void, finish: @escaping @Sendable () async -> Void) {
        writing = write
        finishing = finish
        (events, stream) = AsyncStream.makeStream()
    }

    /// `initialize`, then `initialized`: the protocol's versions this tool speaks offered.
    func open(workspaceUri: String, credential: Credential? = nil) async throws {
        let parameters = InitializeParameters(
            apiVersions: Release.apiVersions, client: ToolIdentity(name: "stateui", version: Release.version),
            workspaceUri: workspaceUri, credential: credential)
        let answer = try await request("initialize", try JSONValue(encoding: parameters)).decode(InitializeResult.self)
        state.withLock { $0.opening = answer }
        try await send(.object(["jsonrpc": .string("2.0"), "method": .string("initialized")]))
    }

    /// What the served tool answered `initialize` with.
    func opened() throws -> InitializeResult {
        guard let answer = state.withLock({ $0.opening }) else { throw ToolingError(.toolFailed, "The connection is not open.") }
        return answer
    }

    /// The answer to `method` asked with `params`; a refusal thrown as the served tool said it.
    func request(_ method: String, _ params: JSONValue) async throws -> JSONValue {
        let id = state.withLock { state in
            defer { state.next += 1 }
            return String(state.next)
        }
        return try await withCheckedThrowingContinuation { continuation in
            let closed = state.withLock { state in
                if !state.closed { state.waiting[id] = continuation }
                return state.closed
            }
            if closed {
                continuation.resume(throwing: ToolingError(.toolFailed, "The served stateui ended before answering \(method)."))
                return
            }
            Task {
                do {
                    try await send(.object(["jsonrpc": .string("2.0"), "id": .string(id), "method": .string(method), "params": params]))
                } catch {
                    answer(id, .failure(error))
                }
            }
        }
    }

    /// `shutdown`, then `exit`, then the end of the served tool's input.
    func close() async {
        _ = try? await request("shutdown", .object([:]))
        try? await send(.object(["jsonrpc": .string("2.0"), "method": .string("exit")]))
        await finishing()
    }

    /// Reads every frame the served tool writes until its output ends, then refuses what still waits.
    func read<Chunks: AsyncSequence>(_ output: Chunks) async where Chunks.Element == [UInt8] {
        var frames = FrameReader()
        do {
            for try await bytes in output {
                for frame in try frames.take(bytes) { receive(frame) }
            }
        } catch {}
        let waiting = state.withLock { state in
            state.closed = true
            defer { state.waiting = [:] }
            return state.waiting
        }
        for (_, continuation) in waiting {
            continuation.resume(throwing: ToolingError(.toolFailed, "The served stateui ended its output."))
        }
        endEvents()
    }

    /// Ends the events, so no one waits for more.
    func endEvents() {
        stream.finish()
    }

    private func receive(_ frame: Data) {
        guard let message = try? ToolingJSON.decoder().decode(JSONValue.self, from: frame), case .object(let fields) = message
        else { return }
        if case .string(let method)? = fields["method"] {
            if method == "operation/event", let params = fields["params"], let event = try? params.decode(OperationEvent.self) {
                stream.yield(event)
            }
            return
        }
        guard case .string(let id)? = fields["id"] else { return }
        if let error = fields["error"] {
            let refusal = (try? error.decode(RPCError.self)).map { $0.data ?? ToolingError(.toolFailed, $0.message) }
            answer(id, .failure(refusal ?? ToolingError(.toolFailed, "The served stateui refused a request.")))
        } else {
            answer(id, .success(fields["result"] ?? .null))
        }
    }

    private func answer(_ id: String, _ result: Result<JSONValue, any Error>) {
        let continuation = state.withLock { $0.waiting.removeValue(forKey: id) }
        continuation?.resume(with: result)
    }

    private func send(_ message: JSONValue) async throws {
        let body = try ToolingJSON.encoder().encode(message)
        try await writing(Array("Content-Length: \(body.count)\r\n\r\n".utf8) + Array(body))
    }
}

extension OutputLines {
    /// A served operation's output, cut into lines per stream as its chunks come.
    final class Streams: Sendable {
        private let lines = Mutex<[StandardStream: OutputLines]>([:])

        /// The whole lines `chunk` completes.
        func take(_ chunk: OutputChunk) -> [ProcessOutput] {
            let bytes = chunk.encoding == .base64 ? Array(Data(base64Encoded: chunk.data) ?? Data()) : Array(chunk.data.utf8)
            let taken = lines.withLock { lines in
                var these = lines[chunk.stream] ?? OutputLines()
                defer { lines[chunk.stream] = these }
                return these.take(bytes)
            }
            return taken.map { ProcessOutput(stream: chunk.stream == .stdout ? .standardOutput : .standardError, text: $0) }
        }

        /// The lines left without an end once the operation ended.
        func finish() -> [ProcessOutput] {
            lines.withLock { lines in
                defer { lines = [:] }
                return lines.sorted { $0.key.rawValue < $1.key.rawValue }.compactMap { stream, these in
                    var these = these
                    return these.finish().map {
                        ProcessOutput(stream: stream == .stdout ? .standardOutput : .standardError, text: $0)
                    }
                }
            }
        }
    }
}
