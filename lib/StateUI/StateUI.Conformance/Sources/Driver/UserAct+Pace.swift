// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIHost

extension UserAct {
    /// Whether how fast the act goes is read off the host's clock as its steps are heard: a pan, a pinch, two fingers
    /// turning.
    var goesAtTheClocksPace: Bool {
        switch self {
        case .pan, .pinch, .rotate: true
        default: false
        }
    }
}
