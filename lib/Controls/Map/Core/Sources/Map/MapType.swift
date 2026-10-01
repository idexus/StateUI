// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUI

/// How the world is drawn.
public enum MapType: Int32, Sendable, HostRepresentable {
    /// Roads and their names - the default.
    case street = 0

    /// Photography from above, no names on it.
    case satellite = 1

    /// The photography with the roads drawn over it.
    case hybrid = 2
}

// A map's kind is a choice a property can be handed as `$x` - see StateChoice.
extension MapType: StateChoice {}
