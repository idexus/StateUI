// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Design: docs/design/core/journeys.md#what-a-run-reads

extension Journey {
    /// The storage and its lanes as they stand, its journey image made now if nothing has yet.
    private func walking() -> (State<Value>.Storage, JourneyLanes<Value>)? {
        guard storage.walkedImage() != nil, let lanes = storage.journeyLanes else { return nil }

        return (storage, lanes)
    }

    /// Where the host's channel shows the value - under the hand, where a hand holds it.
    var walked: Value { walking()?.1.value ?? storage.value }

    /// Where the value is going: the state's own, read without recording.
    var going: Value { storage.value }
}
