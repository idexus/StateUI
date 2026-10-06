// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A dialog for files - one to open, several, or a place to save - as every host reads the act that asks it, and the
/// answer it gives.
/// Design: docs/design/host/runtime.md#files
@_spi(Host) public struct HostFileDialog: Equatable, Sendable {
    /// What the dialog asks for.
    public enum Kind: Equatable, Sendable {
        /// One file to open.
        case open
        /// As many files to open as the user chooses.
        case openSeveral
        /// A place to save.
        case save
    }

    /// What the dialog asks for.
    public let kind: Kind

    /// The kinds of file it offers, in order; none for any file.
    public let types: [FileType]

    /// The name a save suggests, ending in an extension of its types; empty for an open.
    public let name: String

    /// What a save writes.
    public let contents: [UInt8]

    /// The dialog `call` asks for; nil for an act that asks for none.
    public init?(_ call: HostActCall) {
        let arguments = call.arguments
        func kinds(_ index: Int) -> [FileType] { arguments.value(index).flatMap([FileType].init(propValue:)) ?? [] }
        switch call.act {
        case .openFiles:
            kind = arguments.value(1)?.bool == true ? .openSeveral : .open
            types = kinds(0)
            name = ""
            contents = []
        case .saveFile:
            kind = .save
            types = kinds(2)
            name = Self.name(arguments.value(1)?.string ?? "", types: types)
            contents = arguments.value(0)?.bytes ?? []
        default:
            return nil
        }
    }

    /// Every type's extensions, in order, each once: what a dialog filtering by extension alone shows.
    public var extensions: [String] {
        types.flatMap(\.extensions).reduce(into: []) { kept, next in if !kept.contains(next) { kept.append(next) } }
    }

    /// `name` with the first type's first extension added where it ends in none of the types' - unless it is empty.
    /// Design: docs/design/host/runtime.md#files
    public static func name(_ name: String, types: [FileType]) -> String {
        guard !name.isEmpty, let first = types.first?.extensions.first else { return name }
        let lowered = name.lowercased()
        let ends = types.contains { $0.extensions.contains { lowered.hasSuffix("." + $0) } }
        return ends ? name : name + "." + first
    }

    /// The act's answer: the files an open chose, or the file a save wrote - nothing where it was cancelled.
    public func answer(_ files: [ChosenFile]) -> [HostValue] {
        kind == .save ? [files.first.propValue] : [files.propValue]
    }
}
