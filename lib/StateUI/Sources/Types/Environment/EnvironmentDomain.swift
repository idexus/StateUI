// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Which provider a `stateui_set_environment` buffer is about: one byte, the
/// same number in every host.
enum EnvironmentDomain: UInt8 {
    case battery = 1
    case connectivity = 2
    case display = 3
    case locale = 4
    case device = 5
    case app = 6

    /// The application's phase.
    case application = 7
}
