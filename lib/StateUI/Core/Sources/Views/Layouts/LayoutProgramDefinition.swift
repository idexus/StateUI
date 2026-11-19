// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What `MotionLayoutContract.layout` holds: a layout's arithmetic as its element runs it. A `MotionLayout` makes
/// it from its `placements:`; nothing else does, and nothing reads inside it.
/// Design: docs/design/core/layout-program.md#the-program
public struct LayoutProgramDefinition {
    /// The program the host is handed.
    let host: HostLayoutProgram
}
