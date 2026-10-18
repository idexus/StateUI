// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What `.onVisualStateChanged` runs on entering a state: the states it hears by name, nil for every one.
/// Design: docs/design/views/styles.md#hearing-a-state
struct VisualStateListener {
    let states: Set<KeyName>?
    let handler: ValueHandler<KeyName>

    func hears(_ state: KeyName) -> Bool {
        states?.contains(state) ?? true
    }
}
