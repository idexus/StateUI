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

    /// The user moved the scroller from `old` to `new`, as the display's frame saw it: onto its state first, then
    /// the events, as one user's transaction.
    func scrolled(from old: Point, to new: Point) {
        guard let host else { return }

        host.performUserTransaction {
            if old != new, let binding = element.driven[.scrollOffset] {
                host.take([new.x, new.y], through: binding)
            }
            if old.x != new.x, let handler = element.handler(.scrollXChanged) {
                host.dispatch(handler, payload: [.number(new.x)])
            }
            if old.y != new.y, let handler = element.handler(.scrollYChanged) {
                host.dispatch(handler, payload: [.number(new.y)])
            }
        }
    }
}
