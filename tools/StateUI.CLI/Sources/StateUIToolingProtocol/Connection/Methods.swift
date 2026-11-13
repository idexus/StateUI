// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The methods a service answers, each by name with its parameter and result types.
public struct Methods: Sendable {
    private var answers: [String: @Sendable (JSONValue) async -> OutgoingMessage.Outcome] = [:]

    /// No methods.
    public init() {}

    /// The methods' names, in sorted order.
    public var names: [String] { answers.keys.sorted() }

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
        answers[name] = { params in
            let parameters: Parameters
            switch Self.read(Parameters.self, of: name, from: params) {
            case .success(let read): parameters = read
            case .failure(let error): return .error(error)
            }
            do {
                return .result(try JSONValue(encoding: try await answer(parameters)))
            } catch let error as ToolingError {
                return .error(.refused(error))
            } catch {
                return .error(.internalError("\(name) failed: \(error)"))
            }
        }
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

    /// The answer to `name` called with `params`; parameters not sent are read as `{}`.
    func answer(_ name: String, params: JSONValue?) async -> OutgoingMessage.Outcome {
        guard let answer = answers[name] else { return .error(.methodNotFound(name)) }
        return await answer(params ?? .object([:]))
    }
}
