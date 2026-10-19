// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Where a runtime's time goes, stage by stage, in a process started probed (`STATEUI_PROBE=1`): each stage's
/// milliseconds in the last second, how many times it ran and its longest run, written once a second while the
/// runtime works as one line, `StateUI stages: …`. Unprobed, a stage runs as it is.
/// Design: docs/design/host/runtime.md#probes
@MainActor
final class HostProbe {
    /// The stages of a runtime's work, none inside another: a native event's handlers, the core's jobs, a render,
    /// its patch applied, the windows and pages shown after it, the animations, the core's cycle, and what moved
    /// presented to the natives.
    enum Stage: CaseIterable, Sendable {
        case events, jobs, render, apply, chrome, animations, cycle, present

        /// The stage as the line names it.
        var name: String {
            switch self {
            case .events: "events"
            case .jobs: "jobs"
            case .render: "render"
            case .apply: "apply"
            case .chrome: "windows"
            case .animations: "animations"
            case .cycle: "cycle"
            case .present: "present"
            }
        }
    }

    /// The probe of this process, where it was started probed.
    static var running: HostProbe?

    private let write: (String) -> Void
    private var spent: [Stage: Duration] = [:]
    private var longest: [Stage: Duration] = [:]
    private var runs: [Stage: Int] = [:]
    private var second = ContinuousClock.now

    private init(write: @escaping (String) -> Void) {
        self.write = write
    }

    /// Starts probing this process where its environment asks, its lines handed to `write`.
    static func start(
        where diagnostics: DiagnosticText, write: @escaping (String) -> Void = HostLog.writeStandardError
    ) {
        running = diagnostics.probes ? HostProbe(write: write) : nil
    }

    /// Runs `stage`, timed where the process is probed.
    @discardableResult
    static func timed<Result>(_ stage: Stage, _ run: () throws -> Result) rethrows -> Result {
        guard let probe = running else { return try run() }

        let start = ContinuousClock.now
        defer { probe.add(stage, ContinuousClock.now - start) }
        return try run()
    }

    /// One run of `stage`, and the second's line where a second has passed.
    private func add(_ stage: Stage, _ took: Duration) {
        spent[stage, default: .zero] += took
        longest[stage] = max(longest[stage] ?? .zero, took)
        runs[stage, default: 0] += 1

        let now = ContinuousClock.now
        guard now - second >= .seconds(1) else { return }

        write(line)
        second = now
        spent = [:]
        longest = [:]
        runs = [:]
    }

    /// The second's stages that ran: milliseconds in all, runs, longest.
    var line: String {
        let stages = Stage.allCases.compactMap { stage in
            runs[stage].map { runs in
                "\(stage.name) \(Self.milliseconds(spent[stage] ?? .zero)) ms (\(runs)x, "
                    + "most \(Self.milliseconds(longest[stage] ?? .zero)))"
            }
        }
        return "StateUI stages: " + stages.joined(separator: " · ") + "\n"
    }

    /// A duration in milliseconds, one decimal.
    private static func milliseconds(_ duration: Duration) -> String {
        let tenths = Int((Double(duration.components.seconds) * 10_000
            + Double(duration.components.attoseconds) / 1e14).rounded())
        return "\(tenths / 10).\(tenths % 10)"
    }
}
