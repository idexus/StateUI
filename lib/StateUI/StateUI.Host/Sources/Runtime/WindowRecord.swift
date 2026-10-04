// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a platform that restores windows itself keeps of one window to restore it by, the same on every such host:
/// the window's identity, its kind, the text of its value and the values its scene keeps - any window of a scene may
/// be the one that opens it again. One text holds it, and reads back the record it was written from.
/// Design: docs/design/host/runtime.md#restored-windows
@_spi(Host) public struct WindowRecord: Equatable, Sendable {
    /// The window's own identity, which the platform restores it by.
    public let identifier: String

    /// Its kind; nil for a window of the group with no name.
    public let kind: String?

    /// The text of the value it was opened for; nil for none.
    public let value: String?

    /// The values its scene keeps, by key.
    public var kept: [String: HostValue]

    /// A window `identifier` of `kind`, for `value`, its scene keeping `kept`.
    public init(identifier: String, kind: String? = nil, value: String? = nil, kept: [String: HostValue] = [:]) {
        self.identifier = identifier
        self.kind = kind
        self.value = value
        self.kept = kept
    }

    /// The record of the window `element` is now: its identity as given, its kind and value as the tree says, its
    /// scene keeping `kept`.
    @MainActor public init(of element: MountedElement, identifier: String, kept: [String: HostValue]) {
        self.init(
            identifier: identifier, kind: element.value(.windowType)?.name,
            value: element.value(.windowValue)?.string, kept: kept)
    }

    /// The text holding it: a line a field - its name, then its words, apart by a tab - the kept values by key.
    public var text: String {
        var lines = [["window", identifier]]
        if let kind { lines.append(["kind", kind]) }
        if let value { lines.append(["value", value]) }
        for key in kept.keys.sorted() {
            if let word = SceneValueWord.word(of: kept[key]!) { lines.append(["kept", key, word]) }
        }
        return lines.map { $0.map(KeptValuesText.escaped).joined(separator: "\t") + "\n" }.joined()
    }

    /// The record `text` holds; nil where it names no window. A line that says nothing known is passed over.
    public init?(_ text: String) {
        var identifier: String?
        var kind: String?
        var value: String?
        var kept: [String: HostValue] = [:]

        for line in text.split(separator: "\n") {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(KeptValuesText.unescaped)
            switch (fields.first, fields.count) {
            case ("window", 2): identifier = fields[1]
            case ("kind", 2): kind = fields[1]
            case ("value", 2): value = fields[1]
            case ("kept", 3): kept[fields[1]] = SceneValueWord.value(fields[2])
            default: continue
            }
        }

        guard let identifier else { return nil }
        self.init(identifier: identifier, kind: kind, value: value, kept: kept)
    }
}
