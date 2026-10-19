// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The entries within reach of a host's cells as it last said them, and the positions they stood at then.
struct ItemsReach: Equatable {
    var identities: [String] = []
    var positions: [Int] = []
}
