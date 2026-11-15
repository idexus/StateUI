// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// What a run hands an application it starts elsewhere - a simulator, a device, Android, a page - of the tool's
/// environment: each `STATEUI_` variable, a switch such as `STATEUI_TALLY=1`, but `STATEUI_HOST`.
/// Design: docs/design/tooling/runs.md#what-a-run-hands-the-application
struct HandedEnvironment: Sendable, Equatable {
    let variables: [String: String]

    /// What of `environment` a run hands its application.
    init(of environment: [String: String]) {
        variables = environment.filter { $0.key.hasPrefix("STATEUI_") && $0.key != "STATEUI_HOST" }
    }

    var sorted: [(name: String, value: String)] {
        variables.sorted { $0.key < $1.key }.map { (name: $0.key, value: $0.value) }
    }
}
