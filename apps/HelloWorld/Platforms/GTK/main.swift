// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import HelloWorldUI
import StateUI
import StateUIGTK

// Name the application to the host, then hand GTK this thread until the last
// window closes.
HelloWorldApp.register()
GTKHost.run(applicationID: "com.stateui.helloworld")
