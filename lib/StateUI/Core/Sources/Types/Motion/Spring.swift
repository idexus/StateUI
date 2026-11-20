// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A spring's numbers, held to their floors once for every spring StateUI runs - a motion's, a layout body's.
/// Design: docs/design/types/motion.md#spring-numbers
struct Spring: Equatable, Sendable {
    /// How quickly it answers, in milliseconds: at least one.
    let milliseconds: UInt32

    /// How it is damped: 1 comes to rest without passing, below 1 passes and comes back; at least 0.05.
    let damping: Double

    init(response: Duration = .milliseconds(300), damping: Double = 1) {
        milliseconds = max(Motion.milliseconds(of: response), 1)
        self.damping = damping.isFinite ? max(damping, 0.05) : 1
    }

    /// A spring back from the numbers it crossed as: its response in milliseconds, and its damping.
    init(milliseconds: Double, damping: Double) {
        self.init(response: .milliseconds(milliseconds.isFinite ? Int64(max(milliseconds, 0).rounded()) : 300), damping: damping)
    }

    var response: Double { Double(milliseconds) }
}
