// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a window declaration makes, as a scene's tree reads it: the page each of its windows shows - a view of
/// `kind` - and, for windows beside the main one, what opens one, restores one and how they stand.
struct DeclaredWindows {
    /// The kind a session opens one by; nil for the main window.
    let type: WindowType?
    let valueType: Any.Type?
    let kind: String

    /// The page of one window: the one opened, in the scene that has it open; nothing for the main window.
    let page: (_ opened: OpenedWindow?, _ record: SceneRecord?) -> Node

    var restore: (_ text: String) -> AnyHashable? = { _ in nil }
    var hides = false
    var floats = false
    var environments: [(key: ObjectIdentifier, object: AnyObject)] = []
}
