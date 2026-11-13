// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Synchronization

/// The lines a run's program wrote, gathered from both streams for a caller that reads them at its end.
public final class Gathered: Sendable {
    private let written = Mutex<[ProcessOutput]>([])

    /// Nothing gathered.
    public init() {}

    /// Gathers `line`; hand it to ``ProcessRunner/run(_:output:)``.
    @Sendable public func add(_ line: ProcessOutput) {
        written.withLock { $0.append(line) }
    }

    /// The lines of `stream`, in order.
    public func lines(of stream: ProcessOutput.Stream) -> [String] {
        written.withLock { $0.filter { $0.stream == stream }.map(\.text) }
    }
}
