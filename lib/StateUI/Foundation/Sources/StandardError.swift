// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Writes `text` to the standard error, which nothing buffers - every byte of it, a write the system cuts short
/// going on from where it stopped.
///
/// Design: docs/design/foundation/c-library.md#the-environment-and-the-standard-error
@_spi(Host) public func writeStandardError(_ text: String) {
    var text = text
    text.withUTF8 { bytes in
        guard let start = bytes.baseAddress else { return }
        var written = 0

        while written < bytes.count {
            #if os(Windows)
            let wrote = Int(_write(2, start + written, UInt32(bytes.count - written)))
            let interrupted = false
            #elseif os(macOS) || os(iOS) || os(Android) || os(Linux) || os(WASI)
            let wrote = write(2, start + written, bytes.count - written)
            let interrupted = wrote < 0 && errno == EINTR
            #else
            #error("StateUIFoundation knows no standard error on this platform")
            #endif

            if wrote > 0 {
                written += wrote
            } else if !interrupted {
                return
            }
        }
    }
}
