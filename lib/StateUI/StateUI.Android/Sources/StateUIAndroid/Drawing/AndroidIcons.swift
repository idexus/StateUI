// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUI

/// Each icon's Material Symbols drawable, by its name among the application's resources.
extension Icon {
    var androidDrawable: String { "stateui_icon_\(self)" }
}
