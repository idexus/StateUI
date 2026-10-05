// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The host this build is for, to the head that depends on StateUIHead.

#if APPKIT
@_exported import StateUIAppKit
#elseif UIKIT
@_exported import StateUIUIKit
#elseif ANDROID
@_exported import StateUIAndroid
#elseif WINUI
@_exported import StateUIWinUI
#elseif GTK
@_exported import StateUIGTK
#elseif WEB
@_exported import StateUIWeb
#endif
