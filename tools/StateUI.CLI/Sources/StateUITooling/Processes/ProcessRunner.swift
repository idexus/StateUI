// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if canImport(System)
import System
#else
import SystemPackage
#endif
import Subprocess

/// Runs programs for the tool, and stops each with everything it started.
/// Design: docs/design/tooling/processes.md#a-program-and-everything-it-started
public struct ProcessRunner: Sendable {
    /// A runner.
    public init() {}

    /// Runs `request` to its end, handing `output` each line a captured program writes as it comes - from two
    /// tasks at once, standard output and standard error in no order between them.
    ///
    /// A program that runs past its time limit, or whose task is cancelled, is stopped - captured, with every
    /// program it started - and the run returns once they are gone, its outcome saying why.
    ///
    /// - Throws: ``ProcessFailure`` when the program cannot start.
    public func run(
        _ request: ProcessRequest,
        output: @escaping @Sendable (ProcessOutput) -> Void = { _ in }
    ) async throws -> ProcessOutcome {
        #if os(Windows)
        // Design: docs/design/tooling/processes.md#an-argument-array-never-a-shell-line
        if request.arguments.contains(where: \.isEmpty) { throw ProcessFailure.emptyArgument }
        #endif
        return try await withThrowingTaskGroup(of: Race.self) { group in
            group.addTask { .ended(try await execute(request, output: output)) }
            if let timeout = request.timeout {
                group.addTask { try await Task.sleep(for: timeout); return .expired }
            }
            var termination: ProcessOutcome.Termination?
            var stop: ProcessOutcome.Stop?
            while let result = await group.nextResult() {
                switch result {
                case .success(.ended(let ended)):
                    termination = ended
                    group.cancelAll()
                case .success(.expired):
                    stop = .timeout
                    group.cancelAll()
                case .failure(let error):
                    guard error is CancellationError else { group.cancelAll(); throw error }
                }
            }
            guard let termination else { throw CancellationError() }
            return ProcessOutcome(termination: termination, stop: stop ?? (Task.isCancelled ? .cancellation : nil))
        }
    }

    private enum Race: Sendable {
        case ended(ProcessOutcome.Termination)
        case expired
    }

    private func execute(
        _ request: ProcessRequest,
        output: @escaping @Sendable (ProcessOutput) -> Void
    ) async throws -> ProcessOutcome.Termination {
        let configuration = Configuration(
            executable: request.executable.subprocess,
            arguments: Arguments(request.arguments),
            environment: request.environment.subprocess,
            workingDirectory: request.workingDirectory.map { FilePath($0) },
            platformOptions: Self.options(for: request)
        )
        do {
            switch request.streams {
            case .captured:
                let session = ProcessSession(gracePeriod: request.gracePeriod)
                let status: TerminationStatus
                do {
                    status = try await withTaskCancellationHandler {
                        try await Subprocess.run(
                            configuration, input: .none, output: .sequence, error: .sequence
                        ) { execution in
                            session.started(Int(execution.processIdentifier.value))
                            async let standardOutput: Void = Self.drain(
                                execution.standardOutput, as: .standardOutput, to: output)
                            async let standardError: Void = Self.drain(
                                execution.standardError, as: .standardError, to: output)
                            _ = await (standardOutput, standardError)
                        }.terminationStatus
                    } onCancel: {
                        session.stop()
                    }
                } catch {
                    await session.stopped()
                    throw error
                }
                await session.stopped()
                return Self.termination(status)
            case .terminal:
                let result = try await Subprocess.run(
                    configuration,
                    input: .currentStandardInput,
                    output: .currentStandardOutput,
                    error: .currentStandardError
                )
                return Self.termination(result.terminationStatus)
            }
        } catch let error as SubprocessError {
            throw ProcessFailure(error)
        }
    }

    /// Design: docs/design/tooling/processes.md#a-program-and-everything-it-started
    private static func options(for request: ProcessRequest) -> PlatformOptions {
        var options = PlatformOptions()
        let captured = request.streams == .captured
        #if os(Windows)
        options.createProcessGroup = captured
        #else
        options.createSession = captured
        #endif
        options.teardownSequence = [
            .gracefulShutDown(toProcessGroup: captured, allowedDurationToNextStep: request.gracePeriod),
        ]
        return options
    }

    /// Design: docs/design/tooling/processes.md#output-comes-in-lines
    private static func drain(
        _ sequence: SubprocessOutputSequence,
        as stream: ProcessOutput.Stream,
        to output: @Sendable (ProcessOutput) -> Void
    ) async {
        var lines = OutputLines()
        do {
            for try await buffer in sequence {
                let taken = buffer.withUnsafeBytes { lines.take($0) }
                for line in taken { output(ProcessOutput(stream: stream, text: line)) }
            }
        } catch {}
        if let last = lines.finish() { output(ProcessOutput(stream: stream, text: last)) }
    }

    private static func termination(_ status: TerminationStatus) -> ProcessOutcome.Termination {
        switch status {
        case .exited(let code): .exited(Int(code))
        #if !os(Windows)
        case .signaled(let signal): .signaled(Int(signal))
        #endif
        }
    }
}

extension ProcessExecutable {
    fileprivate var subprocess: Executable {
        switch self {
        case .name(let name): .name(name)
        case .path(let path): .path(FilePath(path))
        }
    }
}

extension ProcessEnvironment {
    fileprivate var subprocess: Environment {
        var changes: [Environment.Key: String?] = [:]
        for name in removed { changes.updateValue(nil, forKey: Environment.Key(stringLiteral: name)) }
        for (name, value) in set { changes[Environment.Key(stringLiteral: name)] = value }
        return changes.isEmpty ? .inherit : .inherit.updating(changes)
    }
}

extension ProcessFailure {
    fileprivate init(_ error: SubprocessError) {
        switch error.code {
        case .executableNotFound: self = .notFound(error.description)
        case .failedToChangeWorkingDirectory: self = .directoryUnusable(error.description)
        default: self = .systemFailure(error.description)
        }
    }
}
