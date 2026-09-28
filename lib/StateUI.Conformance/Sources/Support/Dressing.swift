// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUI

/// What a specimen wears: a member's value, or a handler of one of its events.
public protocol Worn: Sendable {
    /// `element` wearing it.
    func worn<Element: ModifiableElement>(by element: Element) -> Element where Element.Modified == Element

    /// `part` - carrying values, hearing no event through `onEvent`, as a menu's item - wearing it; `part` as it was
    /// for what only an element hearing events wears.
    func worn<Part: PropertyContainer>(byPart part: Part) -> Part where Part.Modified == Part
}

extension Worn {
    public func worn<Part: PropertyContainer>(byPart part: Part) -> Part where Part.Modified == Part {
        part
    }
}

/// One member and its value, written through the element's own `setValue`.
public struct Write<Owner: Contract, Value: HostRepresentable & Sendable>: Worn {
    /// The member.
    public let member: ElementProperty<Owner, Value>

    /// Its value.
    public let value: Value

    /// `member` holding `value`.
    public init(_ member: ElementProperty<Owner, Value>, _ value: Value) {
        self.member = member
        self.value = value
    }

    public func worn<Element: ModifiableElement>(by element: Element) -> Element where Element.Modified == Element {
        element.setValue(member, value)
    }

    public func worn<Part: PropertyContainer>(byPart part: Part) -> Part where Part.Modified == Part {
        part.setValue(member, value)
    }
}

/// One event and what hears it, through the element's own `onEvent`.
public struct Hear<Owner: Contract, Value: HostRepresentable & Sendable>: Worn {
    /// The event.
    public let event: ElementEvent<Owner, Value>

    /// What hears it.
    public let handler: @Sendable (Value) async throws -> Void

    /// `event` heard by `handler`.
    public init(_ event: ElementEvent<Owner, Value>, _ handler: @escaping @Sendable (Value) async throws -> Void) {
        self.event = event
        self.handler = handler
    }

    public func worn<Element: ModifiableElement>(by element: Element) -> Element where Element.Modified == Element {
        let handler = handler
        return element.onEvent(event) { value in try await handler(value) }
    }
}

/// One event carrying three values, and what hears them.
public struct HearThree<Owner: Contract, First, Second, Third>: Worn
where First: HostRepresentable & Sendable, Second: HostRepresentable & Sendable, Third: HostRepresentable & Sendable {
    /// The event.
    public let event: ElementEvent<Owner, (First, Second, Third)>

    /// What hears it.
    public let handler: @Sendable (First, Second, Third) async throws -> Void

    /// `event` heard by `handler`.
    public init(
        _ event: ElementEvent<Owner, (First, Second, Third)>,
        _ handler: @escaping @Sendable (First, Second, Third) async throws -> Void
    ) {
        self.event = event
        self.handler = handler
    }

    public func worn<Element: ModifiableElement>(by element: Element) -> Element where Element.Modified == Element {
        let handler = handler
        return element.onEvent(event) { first, second, third in try await handler(first, second, third) }
    }
}

/// One event carrying nothing, and what hears it.
public struct HearDone<Owner: Contract>: Worn {
    /// The event.
    public let event: ElementEvent<Owner, Void>

    /// What hears it.
    public let handler: @Sendable () async throws -> Void

    /// `event` heard by `handler`.
    public init(_ event: ElementEvent<Owner, Void>, _ handler: @escaping @Sendable () async throws -> Void) {
        self.event = event
        self.handler = handler
    }

    public func worn<Element: ModifiableElement>(by element: Element) -> Element where Element.Modified == Element {
        let handler = handler
        return element.onEvent(event) { try await handler() }
    }
}

/// What a case puts on a specimen: the members it writes, and the id it finds it by.
public struct Dressing: Sendable {
    /// What it wears, in order.
    public let worn: [any Worn]

    /// The id the case finds the specimen by.
    public let id: String

    /// A specimen found by `id`, wearing `worn`.
    public init(_ worn: [any Worn] = [], id: String = "specimen") {
        self.worn = worn
        self.id = id
    }

    /// `control` dressed, and found by the id.
    public func dress<Control: View>(_ control: Control) -> any View where Control.Modified == Control {
        wear(control).id(id)
    }

    /// `element` wearing what the dressing holds, found by its kind rather than an id.
    public func wear<Element: ModifiableElement>(_ element: Element) -> Element where Element.Modified == Element {
        var dressed = element
        for each in worn {
            dressed = each.worn(by: dressed)
        }
        return dressed
    }

    /// `part` - a menu's item, a toolbar's - wearing the values the dressing holds; its events are heard through its
    /// own modifiers.
    public func wear<Part: PropertyContainer>(_ part: Part) -> Part where Part.Modified == Part {
        var dressed = part
        for each in worn {
            dressed = each.worn(byPart: dressed)
        }
        return dressed
    }
}
