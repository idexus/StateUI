// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Which platform and architecture this library was compiled for.
public func stateUIPlatform() -> String {
    #if os(Windows)
        let name = "Windows"
    #elseif os(Android)
        let name = "Android"
    #elseif targetEnvironment(macCatalyst)
        let name = "Mac Catalyst"
    #elseif os(iOS)
        #if targetEnvironment(simulator)
            let name = "iOS Simulator"
        #else
            let name = "iOS"
        #endif
    #elseif os(macOS)
        let name = "macOS"
    #elseif os(Linux)
        let name = "Linux"
    #else
        let name = "unknown"
    #endif

    #if arch(arm64)
        let arch = "arm64"
    #elseif arch(x86_64)
        let arch = "x86_64"
    #else
        let arch = "unknown"
    #endif

    return "\(name) (\(arch))"
}
