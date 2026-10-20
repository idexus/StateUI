// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The calls the host layer made on the native halves: each made, applied, its children arranged, a frame
/// presented, a child placed by a run, and each let go as it left.
struct NativeCalls {
    var made = 0
    var applied = 0
    var arranged = 0
    var presented = 0
    var placed = 0
    var left = 0
}
