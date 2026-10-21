// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import HelloWorldUI
import StateUIGTK

// Register the application module, then hand GTK this thread until the last
// window closes.
registerApplication()
StateUIGTK.run(applicationID: "com.stateui.helloworld")
