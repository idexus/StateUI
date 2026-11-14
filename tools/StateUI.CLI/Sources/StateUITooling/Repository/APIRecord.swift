// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

extension ProcessEnvironment {
    /// An API phase's environment: no recording variable a run was handed, the record written where asked.
    /// Design: docs/design/tooling/repository.md#the-api-records
    func forAPIRecord(recording: Bool) -> ProcessEnvironment {
        let held = removing("STATEUI_HOST", "STATEUI_UPDATE_EXPORTS", "STATEUI_STALE_ONLY")
        return recording ? held.setting("STATEUI_UPDATE_EXPORTS", to: "1") : held
    }
}
