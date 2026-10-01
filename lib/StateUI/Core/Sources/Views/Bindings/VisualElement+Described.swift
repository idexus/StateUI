// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension VisualElement {
    /// The described two-way form, for a binding the host cannot carry - a part
    /// of a state, or one made from closures: the value read at build, and each
    /// report written back through the binding.
    /// Design: docs/design/views/bindings.md#two-way-controls
    func described(_ property: Prop, _ value: Binding<Bool>, on event: Event) -> Modified {
        modified {
            $0.props[property] = .bool(value.wrappedValue)
            $0.addHandler(event) {
                if let moved = EventBuffer.current.value()?.bool {
                    value.wrappedValue = moved
                }
            }
        }
    }

    /// The same, for a whole number - a choice.
    func described(_ property: Prop, _ value: Binding<Int>, on event: Event) -> Modified {
        modified {
            $0.props[property] = .number(Double(value.wrappedValue))
            $0.addHandler(event) {
                if let moved = EventBuffer.current.value()?.int {
                    value.wrappedValue = moved
                }
            }
        }
    }

    /// The same, for text - what a field typed into reports.
    func described(_ property: Prop, _ value: Binding<String>, on event: Event) -> Modified {
        modified {
            $0.props[property] = .string(value.wrappedValue)
            $0.addHandler(event) {
                if let typed = EventBuffer.current.value()?.string {
                    value.wrappedValue = typed
                }
            }
        }
    }

    /// The same, for a day - what a date picker reports.
    func described(_ property: Prop, _ value: Binding<CalendarDate>, on event: Event) -> Modified {
        modified {
            $0.props[property] = value.wrappedValue.propValue
            $0.addHandler(event) {
                if let chosen = CalendarDate(EventBuffer.current.value()) {
                    value.wrappedValue = chosen
                }
            }
        }
    }

    /// The same, for a time of day - what a time picker reports.
    func described(_ property: Prop, _ value: Binding<ClockTime>, on event: Event) -> Modified {
        modified {
            $0.props[property] = value.wrappedValue.propValue
            $0.addHandler(event) {
                if let chosen = ClockTime(EventBuffer.current.value()) {
                    value.wrappedValue = chosen
                }
            }
        }
    }
}
