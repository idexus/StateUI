// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The application's scenes as a host keeps them for its next start, for a platform that restores no windows: each
/// scene's kept values and the windows it had open, by their kind and their value's text. The same scenes write the
/// same text.
/// Design: docs/design/host/runtime.md#kept-scenes
@_spi(Host) public struct KeptScenes: Equatable, Sendable {
    /// One scene: its values by key, and its windows, in order.
    public struct Scene: Equatable, Sendable {
        /// Its kept values, by key.
        public var values: [String: HostValue]

        /// Its windows, in order.
        public var windows: [Window]

        /// A scene keeping `values`, with `windows` open.
        public init(values: [String: HostValue] = [:], windows: [Window] = []) {
            self.values = values
            self.windows = windows
        }
    }

    /// A window: its kind, and the text of the value it was opened for, where it was.
    public struct Window: Equatable, Sendable {
        /// The kind a scene declares it under; nil for the group with no name.
        public let kind: String?

        /// The text of the value it was opened for; nil for none.
        public let value: String?

        /// A window of `kind`, for the value written `value`.
        public init(kind: String?, value: String?) {
            self.kind = kind
            self.value = value
        }
    }

    /// The scenes, in order.
    public var scenes: [Scene]

    /// `scenes`, in order.
    public init(scenes: [Scene]) {
        self.scenes = scenes
    }

    /// The scenes `text` holds; a line that says nothing known is passed over.
    public init(_ text: String) {
        scenes = []
        for line in text.split(separator: "\n") {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(KeptValuesText.unescaped)
            switch (fields.first, fields.count) {
            case ("scene", 1):
                scenes.append(Scene())
            case ("value", 3) where !scenes.isEmpty:
                if let value = SceneValueWord.value(fields[2]) { scenes[scenes.count - 1].values[fields[1]] = value }
            case ("window", 1...3) where !scenes.isEmpty:
                let window = Window(kind: fields.dropFirst().first, value: fields.dropFirst(2).first)
                scenes[scenes.count - 1].windows.append(window)
            default:
                continue
            }
        }
    }

    /// The scenes `root` holds, in order - each with the values `values` keeps for it and its windows.
    @MainActor public init(of root: MountedElement?, values: SceneValues) {
        scenes = SceneValues.scenes(of: root).map { scene in
            Scene(
                values: values[SceneValues.key(of: scene)],
                windows: scene.windows.map {
                    Window(kind: $0.value(.windowType)?.name, value: $0.value(.windowValue)?.string)
                })
        }
    }

    /// The text holding the scenes: a line "scene" for each, then a line a value, by key, then a line a window -
    /// its kind and its value where it has them.
    public var text: String {
        scenes.map { scene in
            (["scene"]
                + scene.values.keys.sorted().compactMap { key in
                    SceneValueWord.word(of: scene.values[key]!).map { Self.line(["value", key, $0]) }
                }
                + scene.windows.map { Self.line(["window"] + [$0.kind, $0.value].compactMap { $0 }) })
                .map { $0 + "\n" }.joined()
        }.joined()
    }

    /// A line of `fields`, each escaped, apart by tabs.
    private static func line(_ fields: [String]) -> String {
        fields.map(KeptValuesText.escaped).joined(separator: "\t")
    }
}
