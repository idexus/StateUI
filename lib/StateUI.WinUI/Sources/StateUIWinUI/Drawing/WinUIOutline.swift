// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIWinUI

/// An outline: a rectangle, one with rounded corners, or an ellipse.
enum WinUIOutline: Equatable {
    case rectangle

    /// Corners rounded by a radius in DIPs.
    case rounded(Double)

    case ellipse

    /// A layout's shape as it crosses: its kind, then a rectangle's radius.
    init(container value: HostValue?) {
        guard let parts = value?.values, let kind = parts.first?.enumeration else {
            self = .rectangle
            return
        }

        switch kind {
        case 1: self = .rounded(max(0, parts.value(1)?.number ?? 0))
        case 2: self = .ellipse
        default: self = .rectangle
        }
    }

    /// The outline as the relay takes it, and its radius.
    var relay: (outline: StateUIOutline, radius: Double) {
        switch self {
        case .rectangle: (StateUIOutlineRectangle, 0)
        case .rounded(let radius): (StateUIOutlineRounded, radius)
        case .ellipse: (StateUIOutlineEllipse, 0)
        }
    }
}
