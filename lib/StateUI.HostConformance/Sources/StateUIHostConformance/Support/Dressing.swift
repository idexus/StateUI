// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUI

/// A member a case writes on a control: any member of any tier, written through the control's own `setValue`.
public protocol Written: Sendable {
    /// `control` with the member written on it.
    func written<Control: PropertyContainer>(on control: Control) -> Control where Control.Modified == Control
}

/// One member and its value.
public struct Write<Owner: Contract, Value: HostRepresentable & Sendable>: Written {
    /// The member.
    public let member: ElementProperty<Owner, Value>

    /// Its value.
    public let value: Value

    /// `member` holding `value`.
    public init(_ member: ElementProperty<Owner, Value>, _ value: Value) {
        self.member = member
        self.value = value
    }

    public func written<Control: PropertyContainer>(on control: Control) -> Control where Control.Modified == Control {
        control.setValue(member, value)
    }
}

/// What a case puts on a specimen: the members it writes, and the id it finds it by.
public struct Dressing: Sendable {
    /// The members, written in order.
    public let writes: [any Written]

    /// The id the case finds the specimen by.
    public let id: String

    /// A specimen found by `id`, wearing `writes`.
    public init(_ writes: [any Written] = [], id: String = "specimen") {
        self.writes = writes
        self.id = id
    }

    /// `control` dressed.
    public func dress<Control: View>(_ control: Control) -> any View where Control.Modified == Control {
        var dressed = control
        for write in writes {
            dressed = write.written(on: dressed)
        }
        return dressed.id(id)
    }
}
