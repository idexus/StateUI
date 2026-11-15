// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// The operations of one service: accepted once a token, run, cancelled, and told to the connection that started
/// each, event by event in order.
/// Design: docs/design/tooling/protocol.md#an-operation-and-its-events
public actor Operations {
    /// The work an operation does: its result, written as JSON.
    public typealias Work = @Sendable (OperationContext) async throws -> JSONValue

    private struct Record {
        var snapshot: OperationSnapshot
        var request: JSONValue
        var owner: String
        var channel: EventChannel
        var work: Work?
        var task: Task<Void, Never>?
        var cursors: [StandardStream: Int] = [:]
        var gaps: [StandardStream: Int] = [:]
    }

    private var records: [String: Record] = [:]
    private var tokens: [String: String] = [:]
    private let now: @Sendable () -> String

    /// The operations of a service whose clock reads `now`.
    public init(now: @escaping @Sendable () -> String = Operations.timestamp) {
        self.now = now
    }

    /// The time now, in RFC 3339 UTC.
    @Sendable public static func timestamp() -> String {
        Date().formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }

    /// Accepts `request` - a method and its parameters - under the client's `token`, owned by `owner`; a token
    /// already holding the same request answers with its operation and starts nothing.
    ///
    /// - Returns: The operation's handle, and whether it is new and waits for ``start(_:)``.
    func accept(
        kind: String, token: String, request: JSONValue, owner: String, channel: EventChannel, work: @escaping Work
    ) throws(ToolingError) -> (handle: OperationHandle, isNew: Bool) {
        if let id = tokens[token], let record = records[id] {
            guard record.request == request else {
                throw ToolingError(.requestTokenConflict, "The token \(token) stands for another request.")
            }
            return (record.snapshot.handle, false)
        }
        let id = "op-" + UUID().uuidString.lowercased()
        let snapshot = OperationSnapshot(id: id, kind: kind, requestToken: token, createdAt: now())
        records[id] = Record(snapshot: snapshot, request: request, owner: owner, channel: channel, work: work)
        tokens[token] = id
        return (snapshot.handle, true)
    }

    /// Starts operation `id`'s work, unless a cancel came first.
    func start(_ id: String) {
        guard var record = records[id], record.snapshot.state == .queued, let work = record.work else { return }
        record.work = nil
        record.snapshot.state = .running
        record.snapshot.startedAt = now()
        records[id] = record
        emit(id, .state(.running))
        let context = OperationContext(operationId: id, operations: self)
        records[id]?.task = Task {
            let outcome: Result<JSONValue, any Error>
            do { outcome = .success(try await work(context)) } catch { outcome = .failure(error) }
            self.finish(id, outcome)
        }
    }

    /// Operation `id` whole.
    public func snapshot(_ id: String) throws(ToolingError) -> OperationSnapshot {
        guard let record = records[id] else { throw ToolingError(.notFound, "No operation \(id).") }
        return record.snapshot
    }

    /// Asks operation `id` to stop; asking again changes nothing.
    public func cancel(_ id: String) throws(ToolingError) -> CancelResult {
        guard let record = records[id] else { throw ToolingError(.notFound, "No operation \(id).") }
        switch record.snapshot.state {
        case .queued:
            conclude(id) { $0.state = .cancelled }
            return CancelResult(accepted: true, state: .cancelled)
        case .running:
            records[id]?.snapshot.state = .cancelling
            emit(id, .state(.cancelling))
            record.task?.cancel()
            return CancelResult(accepted: true, state: .cancelling)
        case .cancelling, .cancelled:
            return CancelResult(accepted: true, state: record.snapshot.state)
        case .succeeded, .failed, .interrupted:
            return CancelResult(accepted: false, state: record.snapshot.state)
        }
    }

    /// Cancels every operation `owner` started and returns once each has ended, or once `limit` passed.
    public func stop(ownedBy owner: String, within limit: Duration) async {
        let owned = records.filter { $0.value.owner == owner && !$0.value.snapshot.state.isTerminal }.keys.sorted()
        for id in owned { _ = try? cancel(id) }
        let deadline = ContinuousClock.now + limit
        while owned.contains(where: { records[$0]?.snapshot.state.isTerminal == false }), ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    func progress(_ id: String, _ progress: OperationProgress) {
        guard records[id]?.snapshot.state.isTerminal == false else { return }
        records[id]?.snapshot.progress = progress
        emit(id, .progress(progress))
    }

    func started(_ id: String, _ application: LaunchedApplication) {
        guard records[id]?.snapshot.state.isTerminal == false else { return }
        emit(id, .started(application))
    }

    func output(_ id: String, _ bytes: [UInt8], on stream: StandardStream) {
        guard let record = records[id], !record.snapshot.state.isTerminal else { return }
        for chunk in OutputChunker.chunks(of: bytes) {
            let before = records[id]?.cursors[stream] ?? 0
            records[id]?.cursors[stream] = before + chunk.count
            if record.channel.isCongested {
                if records[id]?.gaps[stream] == nil { records[id]?.gaps[stream] = before }
                continue
            }
            emit(id, .output(OutputChunk(
                stream: stream, encoding: chunk.encoding, data: chunk.data, cursor: Self.cursor(stream, before + chunk.count))))
        }
    }

    private func finish(_ id: String, _ outcome: Result<JSONValue, any Error>) {
        let cancelled = records[id]?.snapshot.state == .cancelling
        conclude(id) { snapshot in
            switch outcome {
            case .success(let result):
                snapshot.state = .succeeded
                snapshot.result = result
            case .failure(let error as ToolingError):
                snapshot.state = .failed
                snapshot.failure = error
            case .failure(is CancellationError) where cancelled:
                snapshot.state = .cancelled
            case .failure(let error):
                snapshot.state = cancelled ? .cancelled : .failed
                if !cancelled { snapshot.failure = ToolingError(.internalError, "\(error)") }
            }
        }
    }

    /// Writes the operation's last state, then its terminal event.
    private func conclude(_ id: String, _ change: (inout OperationSnapshot) -> Void) {
        guard var record = records[id] else { return }
        change(&record.snapshot)
        record.snapshot.finishedAt = now()
        record.task = nil
        records[id] = record
        emit(id, .state(record.snapshot.state))
    }

    /// Sends `event` numbered next - any gap in the output before it first.
    private func emit(_ id: String, _ event: OperationEvent.Event) {
        guard var record = records[id] else { return }
        if case .output = event {} else {
            for stream in StandardStream.allCases {
                guard let from = record.gaps.removeValue(forKey: stream) else { continue }
                let gap = OutputGap(
                    stream: stream, fromCursor: Self.cursor(stream, from),
                    toCursor: Self.cursor(stream, record.cursors[stream] ?? from), replayAvailable: false)
                send(&record, .outputGap(gap))
            }
        }
        send(&record, event)
        records[id] = record
    }

    private func send(_ record: inout Record, _ event: OperationEvent.Event) {
        record.snapshot.lastSequence += 1
        record.channel.send(OperationEvent(
            operationId: record.snapshot.id, sequence: record.snapshot.lastSequence, timestamp: now(), event: event))
    }

    private static func cursor(_ stream: StandardStream, _ offset: Int) -> String { "\(stream.rawValue):\(offset)" }
}
