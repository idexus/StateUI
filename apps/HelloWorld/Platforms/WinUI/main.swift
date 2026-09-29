// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import HelloWorldUI
import StateUIWinUI

// Register the application module, then hand WinUI this thread until the last
// window closes.
stateui_app_register()
StateUIWinUI.run()
