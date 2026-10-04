// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The values each scene keeps for its platform to bring it back with, by the scene's key, the same on every host.
/// Design: docs/design/host/runtime.md#restored-windows
@_spi(Host) public struct SceneValues: Equatable, Sendable {
    private var values: [String: [String: HostValue]] = [:]

    /// Nothing kept yet.
    public init() {}

    /// The values the scene `scene` keeps, by key.
    public subscript(scene: String) -> [String: HostValue] {
        values[scene] ?? [:]
    }

    /// A window the platform kept came back in the scene `scene`, with `kept`: they are the scene's where it opened
    /// with that window, as they are in the core - a scene known here keeps its own.
    public mutating func opened(_ scene: String, keeping kept: [String: HostValue]) {
        if values[scene] == nil { values[scene] = kept }
    }

    /// Keeps a scene's value as the act `persistSceneValue` carries it - the scene's key, the value's key, then the
    /// value. Answers the scene's key; nil for an act that is not one.
    @discardableResult
    public mutating func keep(_ arguments: [HostValue]) -> String? {
        guard arguments.count >= 3, let scene = arguments[0].name, let key = arguments[1].name else { return nil }

        values[scene, default: [:]][key] = arguments[2]
        return scene
    }

    /// Keeps what the scenes `scenes` keep, and nothing of a scene that ended.
    public mutating func keep(only scenes: Set<String>) {
        values = values.filter { scenes.contains($0.key) }
    }

    /// The scene elements `root` holds, in order.
    @MainActor public static func scenes(of root: MountedElement?) -> [MountedElement] {
        guard let root else { return [] }
        return root.type == .scene ? [root] : root.children.filter { $0.type == .scene }
    }

    /// The key a scene's values are kept under: the one the act keeping them names it by.
    @MainActor public static func key(of scene: MountedElement) -> String {
        scene.id.hostValue.string ?? ""
    }
}
