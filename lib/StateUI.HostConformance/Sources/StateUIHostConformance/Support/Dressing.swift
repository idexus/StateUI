// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUI

/// What a specimen wears: a member's value, or a handler of one of its events.
public protocol Worn: Sendable {
    /// `control` wearing it.
    func worn<Control: View>(by control: Control) -> Control where Control.Modified == Control
}

/// One member and its value, written through the control's own `setValue`.
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

    public func worn<Control: View>(by control: Control) -> Control where Control.Modified == Control {
        control.setValue(member, value)
    }
}

/// One event and what hears it, through the control's own `onEvent`.
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

    public func worn<Control: View>(by control: Control) -> Control where Control.Modified == Control {
        let handler = handler
        return control.onEvent(event) { value in try await handler(value) }
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

    /// `control` dressed.
    public func dress<Control: View>(_ control: Control) -> any View where Control.Modified == Control {
        var dressed = control
        for each in worn {
            dressed = each.worn(by: dressed)
        }
        return dressed.id(id)
    }
}
