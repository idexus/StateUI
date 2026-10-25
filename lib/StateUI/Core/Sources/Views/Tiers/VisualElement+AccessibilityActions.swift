// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a screen reader does to the view beside using it.
// Design: docs/design/views/modifiers.md#a-readers-actions

extension VisualElement {
    /// An action a screen reader offers on this view, named by `name` - what a user sees done by a gesture, a swipe
    /// or a menu, offered to a user who cannot see it.
    ///
    ///     MessageRow(message)
    ///         .accessibilityAction("Archive") { archive(message) }
    ///         .accessibilityAction("Delete") { delete(message) }
    ///
    /// A reader offers the actions in the order they are written; a name stands once on a view.
    public func accessibilityAction(_ name: String, perform handler: @escaping @MainActor () throws -> Void) -> Modified {
        modified {
            $0.offersAction(name)
            $0.addHandler(VisualElementContract.accessibilityActionPerformed) { if $0 == name { try handler() } }
        }
    }

    /// The same, with a handler that awaits: its `policy` says what the action does when it comes again while a run is
    /// under way.
    ///
    ///     MessageRow(message).accessibilityAction("Archive", policy: .ignoreWhileRunning) { try await archive(message) }
    public func accessibilityAction(_ name: String, policy: GatePolicy, perform handler: @escaping EventHandler) -> Modified {
        modified {
            $0.offersAction(name)
            $0.addHandler(VisualElementContract.accessibilityActionPerformed, policy: policy) {
                if $0 == name { try await handler() }
            }
        }
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func accessibilityAction(_ name: String, gate: Gate, perform handler: @escaping EventHandler) -> Modified {
        modified {
            $0.offersAction(name)
            $0.addHandler(VisualElementContract.accessibilityActionPerformed, gate: gate) {
                if $0 == name { try await handler() }
            }
        }
    }

    /// Runs when a screen reader steps this view up or down - a swipe up or down on a phone, the reader's keys on a
    /// desktop - on a view made of parts that says it is adjustable.
    ///
    ///     HStack { … }
    ///         .accessibilityRole(.adjustable)
    ///         .accessibilityValue("\(stars) of 5")
    ///         .onAccessibilityAdjusted { step in stars = min(5, max(0, stars + (step == .increment ? 1 : -1))) }
    public func onAccessibilityAdjusted(perform handler: @escaping @MainActor (AccessibilityAdjustment) throws -> Void)
        -> Modified {
        modified { $0.addHandler(VisualElementContract.accessibilityAdjusted, handler) }
    }

    /// The same, with a handler that awaits: its `policy` says what a step does when it comes again while a run is
    /// under way.
    public func onAccessibilityAdjusted(
        _ policy: GatePolicy, perform handler: @escaping ValueEventHandler<AccessibilityAdjustment>
    ) -> Modified {
        modified { $0.addHandler(VisualElementContract.accessibilityAdjusted, policy: policy, handler) }
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onAccessibilityAdjusted(
        gate: Gate, perform handler: @escaping ValueEventHandler<AccessibilityAdjustment>
    ) -> Modified {
        modified { $0.addHandler(VisualElementContract.accessibilityAdjusted, gate: gate, handler) }
    }
}

extension Node {
    /// The node offering `name` among its actions, after those it offers already.
    fileprivate mutating func offersAction(_ name: String) {
        let offered = props[VisualElementContract.accessibilityActions.token].flatMap([String].init(propValue:)) ?? []
        if offered.contains(name) {
            complain("A view offers a screen reader one action of each name: \"\(name)\" was written twice on it, "
                + "and both run.")
        }
        write(VisualElementContract.accessibilityActions, offered + [name])
    }
}
