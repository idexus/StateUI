// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit

/// A spacer: empty room, which asks for none - the stack's arithmetic gives it what its siblings leave.
/// Design: docs/design/host/layout.md#a-spacer
@MainActor
final class UIKitSpacerView: UIView {
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        .zero
    }
}
#endif
