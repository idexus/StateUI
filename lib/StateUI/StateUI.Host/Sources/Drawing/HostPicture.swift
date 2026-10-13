// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A picture a member names, read alike on every host from its value - the theme's already chosen: a file by name,
/// an icon of the platform's own, or an encoded picture's bytes; nil for none.
/// Design: docs/design/host/layout.md#a-picture
@_spi(Host) public enum HostPicture: Hashable, Sendable {
    /// The application's file of that name.
    case file(String)
    /// An icon the platform draws.
    case icon(Icon)
    /// A picture encoded whole, at one pixel a point.
    case bytes([UInt8])

    /// The picture `value` names; nil where it names none.
    public init?(_ value: HostValue?) {
        switch value {
        case .string(let file) where !file.isEmpty: self = .file(file)
        case .enumeration(let number): guard let icon = Icon(rawValue: number) else { return nil }; self = .icon(icon)
        case .bytes(let bytes) where !bytes.isEmpty: self = .bytes(bytes)
        default: return nil
        }
    }

    /// The picture `source` names in the theme in force - its dark file where `dark` and it has one; nil for none.
    public init?(_ source: ImageSource?, dark: Bool) {
        guard let source, !source.isEmpty else { return nil }
        guard source.file.isEmpty else {
            self = .file(dark ? source.dark ?? source.file : source.file)
            return
        }
        self.init(source.propValue)
    }

    /// The value naming the picture, as the tree gives it.
    public var value: HostValue {
        switch self {
        case .file(let file): .string(file)
        case .icon(let icon): .enumeration(icon.rawValue)
        case .bytes(let bytes): .bytes(bytes)
        }
    }

    /// The file's name, where the picture is a file.
    public var file: String? {
        guard case .file(let file) = self else { return nil }
        return file
    }

    /// Words naming the picture alone - a file's name, an icon's, the bytes' count and sum - by which a host tells
    /// the picture it shows from another.
    public var identity: String {
        switch self {
        case .file(let file): return file
        case .icon(let icon): return "icon:\(icon)"
        case .bytes(let bytes):
            // FNV-1a: the same bytes, the same words, on every run.
            let sum = bytes.reduce(UInt64(14_695_981_039_346_656_037)) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
            return "bytes:\(bytes.count):\(sum)"
        }
    }
}
