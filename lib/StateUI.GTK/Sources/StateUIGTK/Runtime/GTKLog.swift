// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Glibc

/// What the host says for whoever reads its log: standard error, unbuffered.
enum GTKLog {
    /// Says something went wrong.
    static func error(_ message: String) {
        let text = "StateUI GTK: " + message + "\n"
        _ = text.withCString { write(2, $0, strlen($0)) }
    }
}
