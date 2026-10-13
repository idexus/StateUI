// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A picture as the relay reads it, one line each: the files a name stands for, the first found shown; an icon as
/// `glyph:` and its Segoe Fluent Icons code point in hex; bytes as `bytes:` and their base64.
/// Design: docs/design/platforms/winui/controls.md#icons
enum WinUIPictures {
    /// The lines `picture` crosses as; none for no picture.
    static func lines(_ picture: HostPicture?) -> [String] {
        switch picture {
        case .file(let name): PictureArithmetic.files(for: name)
        case .icon(let icon): ["glyph:" + String(icon.fluentGlyph, radix: 16, uppercase: true)]
        case .bytes(let bytes): ["bytes:" + Base64.encoded(bytes)]
        case nil: []
        }
    }
}

extension Icon {
    /// The icon's glyph in Segoe Fluent Icons, the font WinUI draws its own icons in.
    var fluentGlyph: UInt32 {
        switch self {
        case .add: 0xE710
        case .remove: 0xE738
        case .close: 0xE711
        case .checkmark: 0xE73E
        case .search: 0xE721
        case .share: 0xE72D
        case .edit: 0xE70F
        case .delete: 0xE74D
        case .settings: 0xE713
        case .info: 0xE946
        case .warning: 0xE7BA
        case .home: 0xE80F
        case .back: 0xE72B
        case .forward: 0xE72A
        case .up: 0xE70E
        case .down: 0xE70D
        case .menu: 0xE700
        case .more: 0xE712
        case .refresh: 0xE72C
        case .download: 0xE896
        case .upload: 0xE898
        case .copy: 0xE8C8
        case .star: 0xE734
        case .heart: 0xEB51
        case .person: 0xE77B
        case .mail: 0xE715
        case .calendar: 0xE787
        case .clock: 0xE917
        case .lock: 0xE72E
        case .play: 0xE768
        case .pause: 0xE769
        case .link: 0xE71B
        }
    }
}
