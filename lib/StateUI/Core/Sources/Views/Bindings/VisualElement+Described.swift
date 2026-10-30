// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension VisualElement {
    /// The described two-way form, for what the host does not carry - a proxy,
    /// or a state it carries in another shape: the value read at build, and each
    /// report written back through it.
    /// Design: docs/design/views/bindings.md#two-way-controls
    func described(_ property: Prop, _ value: some TwoWay<Bool>, on event: Event) -> Modified {
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
    func described(_ property: Prop, _ value: some TwoWay<Int>, on event: Event) -> Modified {
        modified {
            $0.props[property] = .number(Double(value.wrappedValue))
            $0.addHandler(event) {
                if let moved = EventBuffer.current.value()?.int {
                    value.wrappedValue = moved
                }
            }
        }
    }

    /// The same, for a number - what a slider and a stepper report.
    func described(_ property: Prop, _ value: some TwoWay<Double>, on event: Event) -> Modified {
        modified {
            $0.props[property] = .number(value.wrappedValue)
            $0.addHandler(event) {
                if let moved = EventBuffer.current.value()?.number {
                    value.wrappedValue = moved
                }
            }
        }
    }

    /// The same, for text - what a field typed into reports.
    func described(_ property: Prop, _ value: some TwoWay<String>, on event: Event) -> Modified {
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
    func described(_ property: Prop, _ value: some TwoWay<CalendarDate>, on event: Event) -> Modified {
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
    func described(_ property: Prop, _ value: some TwoWay<ClockTime>, on event: Event) -> Modified {
        modified {
            $0.props[property] = value.wrappedValue.propValue
            $0.addHandler(event) {
                if let chosen = ClockTime(EventBuffer.current.value()) {
                    value.wrappedValue = chosen
                }
            }
        }
    }

    /// The same, for a color - what a color picker reports.
    func described(_ property: Prop, _ value: some TwoWay<Color>, on event: Event) -> Modified {
        modified {
            $0.props[property] = value.wrappedValue.propValue
            $0.addHandler(event) {
                if let chosen = EventBuffer.current.value().flatMap(Color.init(propValue:)) {
                    value.wrappedValue = chosen
                }
            }
        }
    }
}
