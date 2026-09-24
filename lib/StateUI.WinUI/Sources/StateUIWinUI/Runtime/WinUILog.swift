// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CRT

/// What the host says for whoever reads its log: standard error, flushed at once.
enum WinUILog {
    /// Says something went wrong.
    static func error(_ message: String) {
        write("StateUI WinUI: " + message + "\n")
    }

    private static func write(_ text: String) {
        fputs(text, stderr)
        fflush(stderr)
    }
}
