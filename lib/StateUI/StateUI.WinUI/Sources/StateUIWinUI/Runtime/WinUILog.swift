// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import WinSDK
@_spi(Host) import StateUIFoundation
@_spi(Host) import StateUIHost

/// Where WinUI's host writes its log: the debugger's output, and standard error.
/// Design: docs/design/host/runtime.md#the-log
enum WinUILog {
    @Sendable static func write(_ line: String) {
        writeStandardError(line)
        line.withCString(encodedAs: UTF16.self) { OutputDebugStringW($0) }
    }
}
