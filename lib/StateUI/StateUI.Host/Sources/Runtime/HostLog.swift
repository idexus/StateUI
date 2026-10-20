// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

import StateUIFoundation

/// What a host says for whoever reads its log rather than its screen, each line naming the host.
/// Design: docs/design/host/runtime.md#the-log
@_spi(Host) public struct HostLog: Sendable {
    /// The host's name, which begins each line.
    public let host: String

    private let output: @Sendable (String) -> Void

    /// A log for `host` written to standard error, which nothing buffers.
    public init(host: String) {
        self.init(host: host, output: Self.writeStandardError)
    }

    /// A log for `host` handed to `output`, line by line.
    public init(host: String, output: @escaping @Sendable (String) -> Void) {
        self.host = host
        self.output = output
    }

    /// Says something went wrong.
    public func error(_ message: String) {
        output(line(message))
    }

    /// Says how something long goes - a run's progress - as it goes.
    public func note(_ message: String) {
        output(line(message))
    }

    /// Hears every complaint the application routes nowhere (`Complaints.route`), each a line of its own.
    /// Design: docs/design/host/runtime.md#the-log
    public func hearComplaints() {
        let log = self
        Complaints.routeByDefault { words in log.note(words) }
    }

    /// The line `message` is written as.
    public func line(_ message: String) -> String {
        "StateUI \(host): \(message)\n"
    }

    /// Writes `text` to file descriptor 2, which nothing buffers.
    public static func writeStandardError(_ text: String) {
        var text = text
        text.withUTF8 { bytes in
            #if os(Windows)
            _ = _write(2, bytes.baseAddress, UInt32(bytes.count))
            #else
            _ = write(2, bytes.baseAddress, bytes.count)
            #endif
        }
    }
}
