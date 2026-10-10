// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a window declaration makes, as a scene's tree reads it: the page each of its windows shows - a view of
/// `kind` - what opens one, what restores one, and how they stand.
struct DeclaredWindows {
    /// The kind a window is opened by; nil for the group launch and *File ▸ New Window* make a window of.
    let type: WindowType?

    /// The type of value one window stands for; nil for a declaration of windows of no value.
    let valueType: Any.Type?

    /// The type of the view a window shows - what an inspector names it by.
    let kind: String

    /// The page of one window: the one opened, in the scene that has it open.
    let page: (_ opened: OpenedWindow?, _ record: SceneRecord?) -> Node

    var restore: (_ text: String) -> AnyHashable? = { _ in nil }

    /// Whether it opens one window - a `Window` - where a group makes as many as are asked for.
    var single = false

    var hides = false
    var floats = false
    var environments: [(key: ObjectIdentifier, object: AnyObject)] = []

    /// Whether it opens a window for `valueType` - none for a window of no value.
    func takes(_ valueType: Any.Type?) -> Bool {
        switch (self.valueType, valueType) {
        case (nil, nil): return true
        case (let declared?, let given?): return ObjectIdentifier(declared) == ObjectIdentifier(given)
        default: return false
        }
    }
}
