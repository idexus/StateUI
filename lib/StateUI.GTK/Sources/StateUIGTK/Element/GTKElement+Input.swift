// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What the user does to the element's view, reported to the core.
extension GTKElement {
    /// An event the view raised, with what it carries, to the handler the tree listens with.
    func send(_ event: Event, _ values: [HostValue]) {
        guard let handler = element.handler(event) else { return }

        host?.dispatch(handler, payload: values)
    }

    /// A value the user changed in the view: onto its state first, then the event with it.
    /// Design: docs/design/host/patches.md#program-write
    func report(_ property: Prop, _ event: Event, _ value: HostValue) {
        guard let host, !ProgramWrite.isWriting else { return }

        let carried: HostStateValue? = switch value {
        case .string(let text): .text(text)
        case .name(let name): .text(name)
        case .bool(let flag): .lanes([flag ? 1 : 0])
        case .number(let number): .lanes([number])
        case .numbers(let numbers): .lanes(numbers)
        case .enumeration(let choice): .lanes([Double(choice)])
        default: nil
        }

        var reported = false
        if let carried, let binding = element.driven[property] {
            if case .lanes(let lanes) = carried, binding.kind == .property {
                reported = host.take(lanes, through: binding)
            } else {
                reported = host.report(carried, through: binding)
            }
        }

        if let handler = element.handler(event) {
            host.dispatch(handler, payload: [value])
        } else if reported {
            host.pump.turn()
        }
    }
}
