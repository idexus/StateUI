// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Synchronization

// Where the library says an application handed it something it cannot use.
// Design: docs/design/core/diagnostics.md#complaints

/// What this library says, once a process, when an application hands it something it cannot use - a value held to
/// what it can be, a write refused. Each goes to the standard output, or where the application routes them.
///
///     Complaints.route { words in logger.notice("\(words)") }
public enum Complaints {
    /// Routes every complaint from now on to `hear`, called on the thread that complains; nil sends them to the
    /// standard output again.
    public static func route(to hear: (@Sendable (String) -> Void)?) {
        Said.shared.route(hear)
    }
}

/// Says, once per process, that a value an application handed this library was
/// not one it could use; the caller carries on with what it used instead.
func complain(_ message: String) {
    Said.shared.say(message)
}

/// Whether anything said so far holds `words` - what a test asks.
func hasComplained(_ words: String) -> Bool {
    Said.shared.said(words)
}

/// What has been said already, so nothing is said twice - from any thread, up to `cap` things.
final class Said: Sendable {
    static let shared = Said(cap: 1000)

    private struct Held {
        var said: Set<String> = []
        var full = false
        var hear: (@Sendable (String) -> Void)?
    }

    private let held = Mutex(Held())
    private let cap: Int

    init(cap: Int) {
        self.cap = cap
    }

    /// Sends what is said to `hear`, or to the standard output where nil.
    func route(_ hear: (@Sendable (String) -> Void)?) {
        held.withLock { $0.hear = hear }
    }

    func say(_ message: String) {
        let (words, hear): (String?, (@Sendable (String) -> Void)?) = held.withLock { held in
            guard !held.said.contains(message) else { return (nil, nil) }
            if held.said.count < cap {
                held.said.insert(message)
                return (message, held.hear)
            }
            // Past the cap, the cap is said once and nothing after it.
            guard !held.full else { return (nil, nil) }
            held.full = true
            return ("more than \(cap) different complaints were said; the rest are not said", held.hear)
        }
        guard let words else { return }

        // Outside the hold: what hears it is somebody else's.
        if let hear { hear(words) } else { print("StateUI: \(words)") }
    }

    func said(_ words: String) -> Bool {
        held.withLock { $0.said.contains { $0.contains(words) } }
    }
}
