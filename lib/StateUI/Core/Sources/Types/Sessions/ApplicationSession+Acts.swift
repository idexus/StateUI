// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The application's own acts - ones with no control behind them - called by their contract's members.
// Design: docs/design/core/acts.md#an-act-is-a-member

extension ApplicationSession {
    /// Performs an act of the application's - one with no control behind it -
    /// handing it the arguments its contract declares and answering with the values
    /// it declares.
    ///
    ///     let level = try await application.call(NotesContract.batteryLevel)
    ///     try await application.call(NotesContract.log, "note")
    ///
    /// Throws `StateUIError.notPerformed` when the host could not perform it - including when no
    /// host answers its name - and `.unreadableAnswer` when the answer is not what the contract
    /// declares. In a run a later event, its task's cancellation or its element
    /// leaving superseded, it throws `CancellationError` and the act never leaves.
    /// It resumes where it was called, and may be called from a handler, a
    /// child task or a detached task. Acts queued without an `await` between them
    /// start in order and finish in whatever order the host's work does. An act of
    /// an element is called through its aim: `Aim.call`.
    ///
    /// - Parameters:
    ///   - act: the member, written with its contract.
    ///   - arguments: its arguments, in the order the contract declares them.
    /// - Returns: the answer, as the contract declares it.
    @discardableResult
    public nonisolated func call<
        Owner: ApplicationTier, each Argument: HostRepresentable, each Answer: HostRepresentable
    >(
        _ act: ElementAct<Owner, (repeat each Argument), (repeat each Answer)>,
        _ arguments: repeat each Argument
    ) async throws -> (repeat each Answer) {
        try await callAct(act, repeat each arguments)
    }

    /// Asks the host to perform an act of the application's without waiting for
    /// it - for an act whose outcome nothing depends on. What it answers, and
    /// whether it failed, reaches nothing here.
    ///
    ///     application.tell(NotesContract.logEvent, "opened the sample")
    ///
    /// It returns at once, and the host performs the act on its next drain. A
    /// name the host has no case for is logged there and never told here - the
    /// difference from `call`, and the reason to reach for that one instead.
    ///
    /// - Parameters:
    ///   - act: the member, written with its contract.
    ///   - arguments: its arguments, in the order the contract declares them.
    public func tell<Owner: ApplicationTier, each Argument: HostRepresentable, Answer>(
        _ act: ElementAct<Owner, (repeat each Argument), Answer>,
        _ arguments: repeat each Argument
    ) {
        tellAct(act, repeat each arguments)
    }
}
