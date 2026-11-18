// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// A write to a pipe whose reader ended - a program gone before its input was written, a client gone before it read -
/// fails rather than ending this process.
/// Design: docs/design/tooling/processes.md#a-pipe-whose-reader-ended
public enum BrokenPipe {
    /// The signal such a write raises on macOS and Linux ignored, once in the process; Windows raises none.
    public static func ignore() {
        _ = ignored
    }

    private static let ignored: Void = {
        #if !os(Windows)
        signal(SIGPIPE, SIG_IGN)
        #endif
    }()
}
