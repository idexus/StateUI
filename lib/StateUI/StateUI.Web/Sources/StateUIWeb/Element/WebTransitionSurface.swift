// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What the Web host moves frame by frame: the host layer's surface, less the window the browser keeps.
/// Design: docs/design/platforms/web/runtime.md#motion
@MainActor
enum WebTransitionSurface {
    static func presents(_ property: Prop, on type: NodeType) -> Bool {
        TransitionSurface.presents(property, on: type, atRest: atRest)
    }

    static let atRest: [NodeType: Set<Prop>] = [.window: [.x, .y, .width, .height]]
}
