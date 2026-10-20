// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension HostActCall {
    /// The address a window's act opens with where it names no window: the window the user is in.
    static let usersWindow: [HostValue] = [.string(""), .string("")]

    /// The address of window `key` of scene `scene`, as a window's act opens with it.
    static func window(_ key: String, of scene: String) -> [HostValue] {
        [.string(scene), .string(key)]
    }
}
