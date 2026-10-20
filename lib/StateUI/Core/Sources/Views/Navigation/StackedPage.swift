// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Who a page above a stack's root is: its depth and the value it stands for, described `depth/value`.
/// Design: docs/design/views/pages.md#an-arrangement-keys-its-pages
struct StackedPage: Hashable, CustomStringConvertible {
    let depth: Int
    let value: AnyHashable

    var description: String { "\(depth)/\(String(describing: value.base))" }
}
