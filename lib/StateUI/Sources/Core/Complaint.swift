// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Dispatch

// WHERE THIS LIBRARY SAYS AN APPLICATION HANDED IT SOMETHING IT CANNOT USE.
//
// A complaint is never a refusal: every one of them is written beside a value
// that carries on working, and nothing here ever depends on one being read. It
// exists because the alternative is silence - a value quietly held to what it
// can be, and an author left wondering why the constant they wrote does
// nothing.

/// Says, once, that a value an application handed this library was not one it
/// could use - and leaves whatever was used instead to the caller.
///
/// ONCE PER MESSAGE PER PROCESS, because the places that complain are
/// MODIFIERS, and a modifier runs on every render: an author who wrote 1.4
/// where a fraction belongs would otherwise be told so as fast as the interface
/// is described, which buries the one line that matters under thousands of
/// copies of itself.
///
/// It goes to standard output, so it reaches a terminal on macOS, the console
/// on iOS, and a shell on Windows and Linux - and **NOTHING on Android**, whose
/// process stdout is not routed anywhere. A complaint is therefore a
/// development aid on four platforms and silence on the fifth, which is exactly
/// why it may never be the only thing standing between an application and
/// working: see `notes/build-run-device.md`.
///
/// - Parameter message: what was wrong and what was done about it.
func complain(_ message: String) {
    Complaints.shared.say(message)
}

/// What has been said already, so nothing is said twice.
///
/// Behind a serial queue rather than a lock, for the reason `State.Storage`
/// gives: libdispatch is on every platform this targets, and Foundation's locks
/// bring ICU on Windows.
private final class Complaints: @unchecked Sendable {
    static let shared = Complaints()

    private let guarded = DispatchQueue(label: "StateUI.Complaints")

    private var said: Set<String> = []

    func say(_ message: String) {
        let first = guarded.sync { said.insert(message).inserted }

        // OUTSIDE THE HOLD, because writing is somebody else's I/O and a
        // complaint is not worth serialising a render behind.
        if first {
            print("StateUI: \(message)")
        }
    }
}
