// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a view's presentation is shared by: the transition id its author wrote, in the scope it names - none, the
/// page - compared as the values they are.
/// Design: docs/design/views/transitions.md#a-shared-presentation
struct SharedKey: Hashable {
    let id: AnyHashable
    let scope: AnyHashable?

    /// The key as a complaint names it: the id, and its scope where one is written.
    var named: String {
        "the transition id \"\(Self.words(id))\"" + (scope.map { " in scope \"\(Self.words($0))\"" } ?? "")
    }

    private static func words(_ value: AnyHashable) -> String {
        (value.base as? String) ?? String(describing: value.base)
    }
}
