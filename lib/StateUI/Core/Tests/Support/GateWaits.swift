// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI

@MainActor
extension Gate {
    /// Waits, a few milliseconds at a time and half a second at most, while a run is under way through the gate.
    func waitWhileBusy() async {
        for _ in 0..<100 {
            guard isBusy else { break }
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    /// Ends whatever a test left running through the gate, so no run outlives it.
    func endEveryRun() async {
        runs.start({}, .cancelPrevious, payload: nil, owner: RunOwner())
        await waitWhileBusy()
    }
}
