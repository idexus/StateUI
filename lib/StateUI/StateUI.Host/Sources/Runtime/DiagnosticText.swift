// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

@_spi(Host) import StateUIFoundation

/// What a runtime writes out for whoever reads its log rather than its screen: the running tally
/// (`STATEUI_TALLY=1`), every inspected pass as text (`STATEUI_INSPECT=1`) and where its time goes, stage by stage
/// (`STATEUI_PROBE=1`, `HostProbe`).
/// Design: docs/design/host/patches.md#what-a-runtime-writes-out
@_spi(Host) public struct DiagnosticText {
    /// Whether the running tally is written after a message worth a line.
    public let tallies: Bool

    /// Whether every pass the inspector records is written as text.
    public let inspects: Bool

    /// Whether the runtime's stages are timed and written once a second.
    public let probes: Bool

    /// How many of its own views the host holds alive, written beside the elements alive; nil where it counts none.
    public var views: (() -> Int)?

    private let output: (String) -> Void
    private var applies = 0
    private var nodes = 0
    private var made = 0
    private var applyMicros = 0.0
    private var longestMicros = 0.0
    private var printedAt = -Double.infinity
    private var appliedAt = -Double.infinity

    /// Text for the switches given, handed to `write`.
    public init(tallies: Bool, inspects: Bool, probes: Bool = false, write: @escaping (String) -> Void) {
        self.tallies = tallies
        self.inspects = inspects
        self.probes = probes
        self.output = write
    }

    /// The switches this process's environment sets, written to its standard error.
    public static var environment: DiagnosticText {
        DiagnosticText(
            tallies: switched("STATEUI_TALLY"), inspects: switched("STATEUI_INSPECT"),
            probes: switched("STATEUI_PROBE"), write: writeStandardError)
    }

    /// One message applied, which began at `began` milliseconds on the runtime's clock.
    @MainActor
    mutating func applied(_ tally: RenderTally, began: Double, core: CoreLink) {
        if inspects {
            let passes = core.takeInspectionLog()
            if !passes.isEmpty { output(passes) }
        }
        guard tallies else { return }

        let micros = RenderTally.micros(ContinuousClock.now - tally.began)
        applies += 1
        nodes += tally.nodes
        made += tally.made
        applyMicros += micros
        longestMicros = max(longestMicros, micros)

        let quiet = began - appliedAt
        appliedAt = began
        guard began - printedAt >= 100 || quiet >= 333 else { return }
        printedAt = began
        output(line(core.tally))
    }

    /// The running totals, as one line.
    private func line(_ core: HostTally) -> String {
        "StateUI tally: applies \(applies)  nodes \(nodes)  made \(made)  kept \(nodes - made)  "
            + "renders \(core.renders)  empty \(core.empty)  refused \(core.refused)  alive \(core.alive)  runs \(core.runs)  "
            + (views.map { "views \($0())  " } ?? "")
            + "apply \(Self.milliseconds(applyMicros / Double(applies))) ms avg / "
            + "\(Self.milliseconds(longestMicros)) ms worst / \(Self.milliseconds(applyMicros)) ms total\n"
    }

    /// Microseconds as milliseconds with two decimals.
    private static func milliseconds(_ micros: Double) -> String {
        let hundredths = Int((micros / 10).rounded())
        let fraction = hundredths % 100
        return "\(hundredths / 100).\(fraction < 10 ? "0" : "")\(fraction)"
    }

    private static func switched(_ name: String) -> Bool {
        environmentVariable(name) == "1"
    }
}
