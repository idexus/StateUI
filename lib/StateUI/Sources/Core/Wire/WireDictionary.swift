// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One session's numbering of every name the wire carries, announced by the first
/// message that uses each. Touched only while encoding, on the host's one thread.
/// Design: docs/design/core/wire.md#the-dictionary
final class WireDictionary {
    private var ids: [String: UInt16] = [:]
    private var pending: [(id: UInt16, name: String)] = []
    private var next: UInt16 = 1

    /// The name's number in this session, assigned and queued for announcement the
    /// first time it is asked for.
    func id(of name: String) -> UInt16 {
        if let id = ids[name] { return id }

        let id = next

        // The counter must not wrap: a number issued twice would rename half a tree.
        precondition(
            id != 0,
            "StateUI: this session has named \(UInt16.max) different things, "
            + "which is every number the wire has for one. What does it is a "
            + "vocabulary that grows without end - a font family, a radio group "
            + "or a visual state built out of a row's own text. Name them from "
            + "a fixed set instead.")

        next &+= 1
        ids[name] = id
        pending.append((id: id, name: name))
        return id
    }

    /// The entries assigned since the last take - what the message being encoded
    /// announces, each once.
    func takePending() -> [(id: UInt16, name: String)] {
        defer { pending.removeAll() }
        return pending
    }
}
