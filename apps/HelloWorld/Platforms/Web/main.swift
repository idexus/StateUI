// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import HelloWorldUI
import StateUIWeb

// Register the application module, then show it in the page; the browser
// calls it from then on.
stateui_app_register()
StateUIWeb.run(name: "HelloWorld")
