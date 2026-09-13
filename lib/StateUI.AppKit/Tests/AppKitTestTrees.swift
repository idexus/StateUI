// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
@_spi(Host) @testable import StateUI

/// The smallest complete application around one piece of content: one
/// scene, one window, one content page. Tests hand it to the renderer so the
/// content mounts where an application mounts it.
func tree(_ content: HostPatch) -> HostPatch {
    var page = HostPatch(id: .manual("page"), type: .contentPage)
    page.children = .arranged([content])
    var window = HostPatch(id: .manual("window"), type: .window)
    window.children = .arranged([page])
    var scene = HostPatch(id: .manual("scene"), type: .scene)
    scene.children = .arranged([window])
    var application = HostPatch(id: .manual("application"), type: .application)
    application.children = .arranged([scene])
    return application
}

/// A later patch of the same application in which only `content` changed.
func changedTree(_ content: HostPatch) -> HostPatch {
    var page = HostPatch(id: .manual("page"), type: .contentPage)
    page.children = .changed([content])
    var window = HostPatch(id: .manual("window"), type: .window)
    window.children = .changed([page])
    var scene = HostPatch(id: .manual("scene"), type: .scene)
    scene.children = .changed([window])
    var application = HostPatch(id: .manual("application"), type: .application)
    application.children = .changed([scene])
    return application
}
#endif
