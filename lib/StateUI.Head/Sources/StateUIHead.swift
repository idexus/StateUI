// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The host this build is for, brought into the graph of the head that depends on StateUIHead; the head imports it
// by its own name - `import StateUIGTK` - the one spelling.

#if APPKIT
import StateUIAppKit
#elseif UIKIT
import StateUIUIKit
#elseif ANDROID
import StateUIAndroid
#elseif WINUI
import StateUIWinUI
#elseif GTK
import StateUIGTK
#elseif WEB
import StateUIWeb
#endif
