// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// An outline - a rectangle, one with rounded corners, a capsule, or an ellipse (`BoxArithmetic.outline`) - as the
/// relay takes it.
extension ContainerShape {
    /// The outline's kind, and its corners' radius at a size `width` by `height` (`BoxArithmetic.cornerRadius`).
    func relay(width: Double, height: Double) -> (outline: StateUIOutline, radius: Double) {
        switch self {
        case .rectangle: (StateUIOutlineRectangle, 0)
        case .roundedRectangle, .capsule:
            (StateUIOutlineRounded, BoxArithmetic.cornerRadius(of: self, width: width, height: height))
        case .ellipse: (StateUIOutlineEllipse, 0)
        }
    }
}
