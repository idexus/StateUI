// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0


// Where the library says an application handed it something it cannot use.
// Design: docs/design/core/diagnostics.md#complaints

/// Says, once per process, that a value an application handed this library was
/// not one it could use; the caller carries on with what it used instead.
func complain(_ message: String) {
    Complaints.shared.say(message)
}

/// What has been said already, so nothing is said twice, behind a `Lock`.
private final class Complaints: @unchecked Sendable {
    static let shared = Complaints()

    private let guarded = Lock()

    private var said: Set<String> = []

    func say(_ message: String) {
        let first = guarded.withLock { said.insert(message).inserted }

        // Outside the hold: writing is somebody else's I/O.
        if first {
            print("StateUI: \(message)")
        }
    }
}
