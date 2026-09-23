// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// An object an element holds for its life - how a page has a session.
// Design: docs/design/core/state.md#element-sessions

/// A composed view's request for an object it keeps for its life.
final class ElementSession {
    /// The type the object is offered as.
    let type: ObjectIdentifier

    /// Makes the object, the first time the element is built.
    let make: () -> AnyObject

    /// The object, once the differ handed it over.
    var object: AnyObject?

    /// A request for an object of a type, made as the element is first built.
    init<Object: AnyObject>(_ type: Object.Type, make: @escaping () -> Object) {
        self.type = ObjectIdentifier(type)
        self.make = make
    }

    /// The object the element holds, or a fresh one outside the differ.
    func held<Object: AnyObject>(as type: Object.Type) -> Object {
        if let object = object as? Object {
            return object
        }

        guard let made = make() as? Object else {
            preconditionFailure("an element session made the wrong type for \(Object.self)")
        }

        object = made
        return made
    }
}
