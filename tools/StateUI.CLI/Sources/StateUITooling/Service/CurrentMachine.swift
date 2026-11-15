// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUIToolingProtocol

extension Machine {
    /// The machine this tool was built for and runs on.
    public static var current: Machine {
        Machine(system: currentSystem, architecture: currentArchitecture)
    }

    private static var currentSystem: String {
        #if os(macOS)
        "macos"
        #elseif os(Linux)
        "linux"
        #elseif os(Windows)
        "windows"
        #else
        "unknown"
        #endif
    }

    private static var currentArchitecture: String {
        #if arch(arm64)
        "arm64"
        #elseif arch(x86_64)
        "x86_64"
        #else
        "unknown"
        #endif
    }
}
