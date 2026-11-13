// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What happened to an operation, numbered in its order: the parameters of `operation/event`.
public struct OperationEvent: Codable, Equatable, Sendable {
    /// What happened.
    public enum Event: Codable, Equatable, Sendable {
        /// The operation came to a state; a terminal one is its last event.
        case state(OperationState)
        /// Its work came further.
        case progress(OperationProgress)
        /// Its program wrote.
        case output(OutputChunk)
        /// Output a client was not sent.
        case outputGap(OutputGap)

        private enum Field: String, CodingKey {
            case kind, state, stage, message, completed, total
            case stream, encoding, data, cursor, fromCursor, toCursor, replayAvailable
        }

        /// Reads an event by its `kind`.
        public init(from decoder: any Decoder) throws {
            let event = try decoder.container(keyedBy: Field.self)
            switch try event.decode(String.self, forKey: .kind) {
            case "state":
                self = .state(try event.decode(OperationState.self, forKey: .state))
            case "progress":
                self = .progress(OperationProgress(
                    stage: try event.decode(String.self, forKey: .stage),
                    message: try event.decodeIfPresent(String.self, forKey: .message),
                    completed: try event.decodeIfPresent(Int.self, forKey: .completed),
                    total: try event.decodeIfPresent(Int.self, forKey: .total)))
            case "output":
                self = .output(OutputChunk(
                    stream: try event.decode(StandardStream.self, forKey: .stream),
                    encoding: try event.decode(OutputChunk.Encoding.self, forKey: .encoding),
                    data: try event.decode(String.self, forKey: .data),
                    cursor: try event.decode(String.self, forKey: .cursor)))
            case "outputGap":
                self = .outputGap(OutputGap(
                    stream: try event.decode(StandardStream.self, forKey: .stream),
                    fromCursor: try event.decode(String.self, forKey: .fromCursor),
                    toCursor: try event.decode(String.self, forKey: .toCursor),
                    replayAvailable: try event.decode(Bool.self, forKey: .replayAvailable)))
            case let kind:
                throw DecodingError.dataCorruptedError(forKey: .kind, in: event, debugDescription: "No event \(kind).")
            }
        }

        /// Writes the event, its `kind` beside its fields.
        public func encode(to encoder: any Encoder) throws {
            var event = encoder.container(keyedBy: Field.self)
            switch self {
            case .state(let state):
                try event.encode("state", forKey: .kind)
                try event.encode(state, forKey: .state)
            case .progress(let progress):
                try event.encode("progress", forKey: .kind)
                try event.encode(progress.stage, forKey: .stage)
                try event.encodeIfPresent(progress.message, forKey: .message)
                try event.encodeIfPresent(progress.completed, forKey: .completed)
                try event.encodeIfPresent(progress.total, forKey: .total)
            case .output(let chunk):
                try event.encode("output", forKey: .kind)
                try event.encode(chunk.stream, forKey: .stream)
                try event.encode(chunk.encoding, forKey: .encoding)
                try event.encode(chunk.data, forKey: .data)
                try event.encode(chunk.cursor, forKey: .cursor)
            case .outputGap(let gap):
                try event.encode("outputGap", forKey: .kind)
                try event.encode(gap.stream, forKey: .stream)
                try event.encode(gap.fromCursor, forKey: .fromCursor)
                try event.encode(gap.toCursor, forKey: .toCursor)
                try event.encode(gap.replayAvailable, forKey: .replayAvailable)
            }
        }
    }

    /// The operation.
    public var operationId: String
    /// The event's place among the operation's events, from 1.
    public var sequence: Int
    /// When it happened, in RFC 3339 UTC.
    public var timestamp: String
    /// What happened.
    public var event: Event

    /// Event `sequence` of operation `operationId`.
    public init(operationId: String, sequence: Int, timestamp: String, event: Event) {
        self.operationId = operationId
        self.sequence = sequence
        self.timestamp = timestamp
        self.event = event
    }
}
