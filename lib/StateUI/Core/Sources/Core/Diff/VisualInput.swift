// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What the user is doing to one element that its visual states follow - holding it down, the pointer over it, the
/// keyboard in it - kept by the element across its builds and read as a state: a change describes the element
/// again, and nothing else.
/// Design: docs/design/views/styles.md#what-the-user-does
final class VisualInput: @unchecked Sendable {
    // Written by the element's handlers and read by the walk, both on the UI thread.
    private var pressed = false
    private var pointerOver = false
    private var focused = false

    /// What the user is doing now, the read made the element's.
    func read() -> (pressed: Bool, pointerOver: Bool, focused: Bool) {
        Renderer.shared.stateRead(self)
        return (pressed, pointerOver, focused)
    }

    /// The user held the element down or let it go.
    func hold(_ down: Bool) {
        guard down != pressed else { return }
        pressed = down
        Renderer.shared.stateChanged(self)
    }

    /// The pointer came over the element or left it.
    func hover(_ over: Bool) {
        guard over != pointerOver else { return }
        pointerOver = over
        Renderer.shared.stateChanged(self)
    }

    /// The keyboard came into the element or left it.
    func focus(_ within: Bool) {
        guard within != focused else { return }
        focused = within
        Renderer.shared.stateChanged(self)
    }
}
