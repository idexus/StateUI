// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What applying one message costs the runtime, kept while an inspector records.
/// Design: docs/design/host/patches.md#what-a-message-costs
struct RenderTally {
    let began = ContinuousClock.now
    var nodes = 0
    var made = 0
    var adopted = 0

    /// Each scene's part, by the scene's key.
    var scenes: [ElementId: Duration] = [:]

    static func micros(_ duration: Duration) -> Double {
        let (seconds, attoseconds) = duration.components
        return Double(seconds) * 1_000_000 + Double(attoseconds) / 1_000_000_000_000
    }
}
