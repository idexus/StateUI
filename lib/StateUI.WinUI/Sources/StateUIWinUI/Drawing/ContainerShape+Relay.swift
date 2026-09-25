// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIWinUI

/// An outline - a rectangle, one with rounded corners, or an ellipse (`BoxArithmetic.outline`) - as the relay takes
/// it.
extension ContainerShape {
    /// The outline's kind, and a rounded rectangle's radius.
    var relay: (outline: StateUIOutline, radius: Double) {
        switch self {
        case .rectangle: (StateUIOutlineRectangle, 0)
        case .roundedRectangle(let radius): (StateUIOutlineRounded, radius)
        case .ellipse: (StateUIOutlineEllipse, 0)
        }
    }
}
