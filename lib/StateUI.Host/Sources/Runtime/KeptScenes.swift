// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The application's scenes as a host keeps them for its next start, for a platform that restores no windows: each
/// scene's kept values, and the windows of a kind of its own it had open, by their kind and their value's text. The
/// same scenes write the same text.
/// Design: docs/design/host/runtime.md#kept-scenes
@_spi(Host) public struct KeptScenes: Equatable, Sendable {
    /// One scene: its values by key, and its windows of a kind of their own, in order.
    public struct Scene: Equatable, Sendable {
        /// Its kept values, by key.
        public var values: [String: HostValue]

        /// Its windows of a kind of their own, in order.
        public var windows: [Window]

        /// A scene keeping `values`, with `windows` open.
        public init(values: [String: HostValue] = [:], windows: [Window] = []) {
            self.values = values
            self.windows = windows
        }
    }

    /// A window of a kind of its own: the kind, and the text of the value it was opened for, where it was.
    public struct Window: Equatable, Sendable {
        /// The kind a scene declares it under.
        public let kind: String

        /// The text of the value it was opened for; nil for none.
        public let value: String?

        /// A window of `kind`, for the value written `value`.
        public init(kind: String, value: String?) {
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
                if let value = Self.value(fields[2]) { scenes[scenes.count - 1].values[fields[1]] = value }
            case ("window", 2) where !scenes.isEmpty:
                scenes[scenes.count - 1].windows.append(Window(kind: fields[1], value: nil))
            case ("window", 3) where !scenes.isEmpty:
                scenes[scenes.count - 1].windows.append(Window(kind: fields[1], value: fields[2]))
            default:
                continue
            }
        }
    }

    /// The scenes `root` holds, in order - each with the values `values` keeps for it by its key, and its windows of
    /// a kind of their own.
    @MainActor public init(of root: MountedElement?, values: [String: [String: HostValue]]) {
        scenes = Self.scenes(of: root).map { scene in
            Scene(
                values: values[Self.key(of: scene)] ?? [:],
                windows: scene.windows.compactMap { window in
                    window.value(.windowType)?.name.map { Window(kind: $0, value: window.value(.windowValue)?.string) }
                })
        }
    }

    /// The scene elements `root` holds, in order.
    @MainActor static func scenes(of root: MountedElement?) -> [MountedElement] {
        guard let root else { return [] }
        return root.type == .scene ? [root] : root.children.filter { $0.type == .scene }
    }

    /// The key a scene's values are kept under: the one the act keeping them names it by.
    @MainActor static func key(of scene: MountedElement) -> String {
        scene.id.hostValue.string ?? ""
    }

    /// The text holding the scenes: a line "scene" for each, then a line a value, by key, then a line a window.
    public var text: String {
        scenes.map { scene in
            (["scene"]
                + scene.values.keys.sorted().compactMap { key in
                    Self.word(of: scene.values[key]!).map { Self.line(["value", key, $0]) }
                }
                + scene.windows.map { Self.line(["window", $0.kind] + ($0.value.map { [$0] } ?? [])) })
                .map { $0 + "\n" }.joined()
        }.joined()
    }

    /// A line of `fields`, each escaped, apart by tabs.
    private static func line(_ fields: [String]) -> String {
        fields.map(KeptValuesText.escaped).joined(separator: "\t")
    }

    /// A value as its words, its kind's letter first; nil for a value no scene keeps.
    private static func word(of value: HostValue) -> String? {
        if let bool = value.bool { return bool ? "btrue" : "bfalse" }
        if let number = value.number { return "n\(number)" }
        return value.string.map { "s\($0)" }
    }

    /// The value words of `word`'s kind read as; nil for words of no kind.
    private static func value(_ word: String) -> HostValue? {
        let words = String(word.dropFirst())
        switch word.first {
        case "b": return .bool(words == "true")
        case "n": return Double(words).map { .number($0) }
        case "s": return .string(words)
        default: return nil
        }
    }
}
