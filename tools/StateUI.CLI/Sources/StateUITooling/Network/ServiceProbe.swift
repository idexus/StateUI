// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol
import Synchronization

/// Whether a stateui service answers at a place, and whether it admits this machine - each asked within a few
/// seconds, as a place that answers nothing would hold a connection for minutes.
/// Design: docs/design/tooling/service.md#a-service-probed
public enum ServiceProbe {
    /// What a place answered.
    public enum Answer: Equatable, Sendable {
        /// A paired machine's service admitted this one, and said what it builds.
        case admitted(ServerInfo)
        /// A stateui service answers, and admits this machine not: unpaired, or its pairing gone.
        case notAdmitted(String)
        /// A stateui service answers for another machine than the one paired or declared.
        case anotherMachine(String)
        /// No stateui service answers there.
        case unreached(String)
    }

    /// How long a place is given to answer.
    static let limit: Duration = .seconds(3)

    /// What `machine`'s service answers: admitted with what it builds, refused, or nothing.
    public static func check(_ machine: RemoteMachine) async -> Answer {
        let tool = ServedTool(remote: machine, workspaceUri: "file:///")
        do {
            let info = try await within { try await tool.query("server/info", .object([:])).decode(ServerInfo.self) }
            return .admitted(info)
        } catch let error as ToolingError where error.message.contains("not paired") {
            return .notAdmitted(error.message)
        } catch let error as ToolingError where error.message.hasPrefix(ServedTool.anotherMachine) {
            return .anotherMachine(error.message)
        } catch {
            return await probe(machine.address, port: machine.port) == nil
                ? .notAdmitted(Self.words(error)) : .unreached(Self.words(error))
        }
    }

    /// Why no stateui service answers at `address` on `port`; nil where one does - it answers a challenge, which no
    /// pairing is asked for.
    public static func probe(_ address: String, port: UInt16) async -> String? {
        let tool = ServedTool(address: address, port: port, workspaceUri: "file:///")
        do {
            _ = try await within { try await tool.beforeOpening("service/challenge", .object([:])).decode(Challenge.self) }
            return nil
        } catch {
            return words(error)
        }
    }

    /// `work`'s result, or a failure once `limit` passed - whichever comes first; a connection still waiting is left to
    /// end by itself, as a task group would wait for it.
    private static func within<Result: Sendable>(_ work: @escaping @Sendable () async throws -> Result) async throws -> Result {
        try await withCheckedThrowingContinuation { continuation in
            let settled = Mutex(false)
            let finish = { @Sendable (outcome: Swift.Result<Result, any Error>) in
                guard settled.withLock({ was in defer { was = true }; return !was }) else { return }
                continuation.resume(with: outcome)
            }
            Task.detached {
                do { finish(.success(try await work())) } catch { finish(.failure(error)) }
            }
            Task.detached {
                try? await Task.sleep(for: limit)
                finish(.failure(ToolingError(.toolFailed, "nothing answered within \(limit.components.seconds) seconds")))
            }
        }
    }

    private static func words(_ error: any Error) -> String {
        (error as? ToolingError)?.message ?? "\(error)"
    }
}
