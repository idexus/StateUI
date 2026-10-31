// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension VisualElement {
    /// The described two-way form, for a value the library works out itself and the host does not carry - a
    /// sheet's presentation, a picker's place: the value read at build, and each report written back through
    /// `write`.
    /// Design: docs/design/views/bindings.md#two-way-controls
    func described(
        _ property: Prop, read: () -> Bool, write: @escaping @MainActor (Bool) -> Void, on event: Event
    ) -> Modified {
        modified {
            $0.props[property] = .bool(read())
            $0.addHandler(event) {
                if let moved = EventBuffer.current.value()?.bool {
                    write(moved)
                }
            }
        }
    }

    /// The same, for a whole number - a choice's place.
    func described(
        _ property: Prop, read: () -> Int, write: @escaping @MainActor (Int) -> Void, on event: Event
    ) -> Modified {
        modified {
            $0.props[property] = .number(Double(read()))
            $0.addHandler(event) {
                if let moved = EventBuffer.current.value()?.int {
                    write(moved)
                }
            }
        }
    }
}
