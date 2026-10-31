// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@_spi(Host) import StateUIHost

@_spi(Host) extension HostShare {
    /// What Apple's share sheets take: the words, then the link as an address - each only where it is given.
    public var items: [Any] {
        var items: [Any] = []
        if let text { items.append(text) }
        if let link = link.flatMap(URL.init(string:)) { items.append(link) }
        return items
    }
}
