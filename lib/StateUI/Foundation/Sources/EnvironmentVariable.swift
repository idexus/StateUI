// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The value of one of the process's environment variables, nil where it holds none.
///
///     let probes = environmentVariable("STATEUI_PROBE") == "1"
///
/// Design: docs/design/foundation/c-library.md#the-environment-and-the-standard-error
@_spi(Host) public func environmentVariable(_ name: String) -> String? {
    #if os(Windows)
    var value: UnsafeMutablePointer<CChar>?
    var count = 0
    guard _dupenv_s(&value, &count, name) == 0, let value else { return nil }
    defer { free(value) }
    return String(cString: value)
    #elseif os(macOS) || os(iOS) || os(Android) || os(Linux) || os(WASI)
    return getenv(name).map { String(cString: $0) }
    #else
    #error("StateUIFoundation knows no environment on this platform")
    #endif
}
