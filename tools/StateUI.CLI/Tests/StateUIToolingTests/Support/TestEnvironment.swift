// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif os(Windows)
import ucrt
#endif

/// This test process's own environment, which the programs it runs inherit.
enum TestEnvironment {
    /// Sets `name` to `value`; `nil` takes it away.
    static func set(_ name: String, _ value: String?) {
        #if os(Windows)
        _putenv_s(name, value ?? "")
        #else
        if let value { setenv(name, value, 1) } else { unsetenv(name) }
        #endif
    }
}
