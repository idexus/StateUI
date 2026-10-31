// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension VisualElement {
    /// The described two-way form, for a value the library works out itself and the host does not carry - a
    /// sheet's presentation, a picker's place: the value read as the element is described, and each report
    /// written back through `write`.
    /// Design: docs/design/views/bindings.md#two-way-controls
    func described(
        _ property: Prop, read: @escaping @MainActor () -> Bool, write: @escaping @MainActor (Bool) -> Void,
        on event: Event
    ) -> Modified {
        modified {
            // Read as the element is described: the element is the reader, never the body that wrote it.
            $0.readsWhenDescribed { $0.props[property] = .bool(read()) }
            $0.addHandler(event) {
                if let moved = EventBuffer.current.value()?.bool {
                    write(moved)
                }
            }
        }
    }

    /// The same, for a whole number - a choice's place.
    func described(
        _ property: Prop, read: @escaping @MainActor () -> Int, write: @escaping @MainActor (Int) -> Void,
        on event: Event
    ) -> Modified {
        modified {
            $0.readsWhenDescribed { $0.props[property] = .number(Double(read())) }
            $0.addHandler(event) {
                if let moved = EventBuffer.current.value()?.int {
                    write(moved)
                }
            }
        }
    }
}
