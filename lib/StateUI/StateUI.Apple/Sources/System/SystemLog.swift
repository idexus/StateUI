// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import os
@_spi(Host) import StateUIFoundation
@_spi(Host) import StateUIHost

/// Where a host of Apple's platforms writes its log: the system's log, which Console and Xcode read whatever started
/// the application, and standard error, which a terminal and a test run read.
/// Design: docs/design/host/runtime.md#the-log
@_spi(Host)
public enum SystemLog {
    /// What writes `host`'s lines to both.
    public static func output(host: String) -> @Sendable (String) -> Void {
        let logger = Logger(subsystem: "StateUI", category: host)
        return { line in
            writeStandardError(line)
            let words = line.hasSuffix("\n") ? String(line.dropLast()) : line
            logger.notice("\(words, privacy: .public)")
        }
    }
}
