// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An element that can hold the keyboard - a control taking the focus, or a layout holding the view that does - and
/// so hear the keys it takes.
/// Design: docs/design/types/keyboard.md#a-views-keys
public protocol KeyboardElement: View {}

extension KeyboardElement {
    /// Runs when one of `keys` is pressed while the element holds the keyboard, or holds the view that does - the
    /// nearest such element naming the key hears it; with nothing holding the keyboard, the page's content does.
    /// The element takes the keys it names, a field inside it no longer gets them, and every other key goes on as
    /// before. A key held with the platform's own key or Alt is a shortcut's, never a view's.
    ///
    ///     VStack { … }
    ///         .onKeyPressed(.upArrow, .downArrow) { key in move(key == .upArrow ? -1 : 1) }
    public func onKeyPressed(_ keys: Key..., perform handler: @escaping @MainActor (Key) throws -> Void) -> Modified {
        taking(keys, gate: .none) { key in try handler(key) }
    }

    /// The same, with a handler that awaits: its `gate` says what a key does when it comes again while a run is
    /// under way.
    ///
    ///     VStack { … }.onKeyPressed(.escape, gate: .ignoreWhileRunning) { _ in try await close() }
    public func onKeyPressed(_ keys: Key..., gate: some Gate, perform handler: @escaping ValueEventHandler<Key>)
        -> Modified {
        taking(keys, gate: gate, handler)
    }

    /// A handler that awaits passes through a gate.
    @available(*, unavailable, message: "a handler that awaits passes through a gate: .onKeyPressed(.escape, gate: closing) { key in … } with @State var closing = Gatekeeper(.ignoreWhileRunning) - or gate: .none")
    public func onKeyPressed(_ keys: Key..., perform handler: @escaping ValueEventHandler<Key>) -> Modified {
        fatalError("unavailable")
    }

    /// The element taking `keys` beside those it takes already, `handler` hearing those alone.
    private func taking(_ keys: [Key], gate: some Gate, _ handler: @escaping ValueEventHandler<Key>) -> Modified {
        // One `modified`: chaining would return `Modified.Modified`.
        modified {
            let taken = $0.props[KeyboardElementContract.keysTaken.token].flatMap([Key].init(propValue:)) ?? []
            $0.write(KeyboardElementContract.keysTaken, Key.ordered(taken + keys))
            $0.addHandler(KeyboardElementContract.keyPressed, gate: gate) { key in
                if keys.contains(key) { try await handler(key) }
            }
        }
    }
}
