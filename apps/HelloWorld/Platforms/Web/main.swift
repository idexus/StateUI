// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import HelloWorldUI
import StateUI
import StateUIWeb

// Name the application to the host, then show it in the page; the browser
// calls it from then on.
HelloWorldApp.register()
WebHost.run(name: "HelloWorld", applicationID: "com.stateui.helloworld")
