// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension ElementValues {
    /// The number a control of a range is written as its value and its ends apply, the same on every host: the
    /// tree's where the tree changed the value or an end - a range widened over a value the control stood clamped
    /// at shows it - else `standing`, the one the control shows, so a hand on it is never argued with.
    /// Design: docs/design/host/runtime.md#a-value-in-a-range
    public func written<Owner: Contract>(
        _ value: ElementProperty<Owner, Double>, within ends: [ElementProperty<Owner, Double>], standing: Double
    ) -> Double {
        guard let tree = self[value], changed(value) || ends.contains(where: { changed($0) }) else { return standing }

        return tree
    }
}
