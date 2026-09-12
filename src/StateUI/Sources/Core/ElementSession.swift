// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// An object an element holds FOR ITS LIFE - made the first time the element is
// built, kept on it across every build after, and offered to everything under
// it by its type, the element's own `@Environment` included.
//
// It is how a page has a session: a `ContentPage` is a value the parent's
// closure constructs afresh on every render, so nothing stored on it outlives
// a build - the element does. The differ keeps the object on the element's
// `RenderedNode`, hands it to the page's closure through this request, and
// puts it in the scope before the page's slots resolve. See
// Types/PageSession.swift.

/// A composed view's request for an object it keeps for its life.
final class ElementSession {
    /// The type the object is offered as.
    let type: ObjectIdentifier

    /// Makes the object, the first time the element is built.
    let make: () -> AnyObject

    /// The object, once the differ has handed it over - nothing while a view
    /// is built outside the differ, which then answers with a fresh one.
    var object: AnyObject?

    /// A request for an object of a type, made as the element is first built.
    ///
    /// - Parameters:
    ///   - type: what the object is offered as.
    ///   - make: makes it.
    init<Object: AnyObject>(_ type: Object.Type, make: @escaping () -> Object) {
        self.type = ObjectIdentifier(type)
        self.make = make
    }

    /// The object the element holds - or a fresh one, for a view built
    /// outside the differ.
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
