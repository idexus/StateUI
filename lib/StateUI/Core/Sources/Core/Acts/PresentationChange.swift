// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a change of the presentation started, awaited apart from the writes that made it.
// Design: docs/design/core/journeys.md#a-change-and-what-it-started

/// A change of the presentation as `Aim.presentationChange(_:)` answers it: `applied()` waits until a host took
/// its writes, `settled()` for how the movements they started ended.
///
///     let closing = try panel.presentationChange { isOpen = false }
///     if try await closing.settled() == .settled { … }
///
/// The change watches what its writes started under the aimed view. It stops nothing, a movement started later
/// is no part of it, and it ends whether or not anybody waits.
@MainActor
public final class PresentationChange {
    private let application = Awaited<PresentationApplication>()
    private let result = Awaited<PresentationResult>()

    init() {}

    /// What the host answered so far, each nil until it has.
    var answered: (applied: PresentationApplication?, settled: PresentationResult?) {
        (application.outcome, result.outcome)
    }

    /// Waits until a host took the change's writes, and answers whether anything shows the aimed view.
    /// Answered already, it answers at once, as often as asked.
    ///
    /// - Throws: `CancellationError` where the waiting task is cancelled; the change goes on.
    @discardableResult
    public func applied() async throws -> PresentationApplication {
        try await application.value()
    }

    /// Waits until every movement the change's writes started under the aimed view has ended, and answers how.
    /// A movement started later does not prolong the wait. Answered already, it answers at once.
    ///
    /// - Throws: `CancellationError` where the waiting task is cancelled; the change and its movements go on.
    @discardableResult
    public func settled() async throws -> PresentationResult {
        try await result.value()
    }

    /// The host's word that the writes were applied; a host that went shows nothing.
    func land(applied reply: Reply) {
        guard case .finished(let values) = reply, values.first?.number == 1 else {
            application.end(.notPresented)
            return
        }
        application.end(.applied)
    }

    /// The host's word of how the movements ended; a host that went shows nothing.
    func land(settled reply: Reply) {
        guard case .finished(let values) = reply, let coded = Self.result(coded: values.compactMap(\.number)) else {
            result.end(.notPresented)
            return
        }
        result.end(coded)
    }

    /// A result as the numbers a host's answer carries: 0 for nothing shown, 1 for settled, 2 and each reason's
    /// place in the order they are declared for interrupted.
    static func code(of result: PresentationResult) -> [Double] {
        switch result {
        case .notPresented: [0]
        case .settled: [1]
        case .interrupted(let reasons):
            [2] + PresentationInterruption.declared.indices
                .filter { reasons.contains(PresentationInterruption.declared[$0]) }.map(Double.init)
        }
    }

    private static func result(coded numbers: [Double]) -> PresentationResult? {
        switch numbers.first {
        case 0: return .notPresented
        case 1: return .settled
        case 2:
            let all = PresentationInterruption.declared
            let reasons = numbers.dropFirst().compactMap { Int(exactly: $0) }.filter(all.indices.contains).map { all[$0] }
            return reasons.isEmpty ? nil : .interrupted(reasons)
        default: return nil
        }
    }
}

extension Aim where Target: ViewProperties {
    /// Makes a change of the presentation and answers what to await of it: `update` writes the states, and the
    /// change watches every movement those writes start under the view this aims at.
    ///
    ///     @Aim(VStack.self) private var panel
    ///
    ///     let opening = try panel.presentationChange { isOpen = true }
    ///     try await opening.settled()
    ///
    /// - Parameter update: the writes, run at once, before this returns.
    /// - Returns: the change, to await its application and its end.
    /// - Throws: where the aim reached no view, or two; `update` is not run then.
    public func presentationChange(_ update: () -> Void) throws -> PresentationChange {
        _ = try target
        // A change made inside another's writes is that one's too.
        let board = Renderer.shared.board
        let outer = board.recording
        board.recording = []
        update()
        let written = board.recording ?? []
        board.recording = outer?.union(written)
        return Renderer.shared.change(aimedAt: place ?? [], writing: written)
    }
}
