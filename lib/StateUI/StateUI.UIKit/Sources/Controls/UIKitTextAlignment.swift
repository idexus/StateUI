// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension NSTextAlignment {
    /// Where words sit across their room, as UIKit draws them: a line's start and end as `direction` reads them
    /// (`TextAlignment.edge(in:)`).
    init(_ alignment: TextAlignment, in direction: UIUserInterfaceLayoutDirection) {
        self.init(alignment.edge(in: direction == .rightToLeft ? .rightToLeft : .leftToRight))
    }

    /// Words standing at `edge` of their room.
    init(_ edge: TextEdge) {
        self = switch edge {
        case .left: .left
        case .center: .center
        case .right: .right
        }
    }
}
#endif
