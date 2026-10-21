// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The window a window's act asks in, as its first two arguments name it - its scene's key and its own, both empty
/// for the window the user is in - and the arguments the act has after them.
/// Design: docs/design/core/acts.md#a-windows-acts
@_spi(Host) public struct AskedWindow: Equatable, Sendable {
    /// The key of the window's scene; empty for the window the user is in.
    public let scene: String

    /// The window's own key in its scene; empty for the window the user is in.
    public let key: String

    /// The acts a window asks: a question, a file dialog, the keyboard taken down.
    public static let acts: Set<Act> = [
        .alert, .confirm, .chooseAction, .prompt, .openFiles, .saveFile, .share, .hideOnScreenKeyboard,
    ]

    /// The window `call` asks in; nil for an act no window asks.
    public init?(_ call: HostActCall) {
        guard Self.acts.contains(call.act) else { return nil }
        scene = call.arguments.value(0)?.string ?? ""
        key = call.arguments.value(1)?.string ?? ""
    }

    /// Whether the act names no window, and asks in the one the user is in.
    public var isTheUsers: Bool { scene.isEmpty }

    /// The window's element under `root`; nil where it is not open.
    @MainActor public func element(in root: MountedElement?) -> MountedElement? {
        guard let scene = SceneValues.scenes(of: root).first(where: { SceneValues.key(of: $0) == self.scene })
        else { return nil }
        return scene.windows.first { $0.id.hostValue.string == key }
    }

    /// `call`'s arguments after the window it names - all of them for an act no window asks.
    public static func arguments(of call: HostActCall) -> [HostValue] {
        acts.contains(call.act) ? Array(call.arguments.dropFirst(2)) : call.arguments
    }
}
