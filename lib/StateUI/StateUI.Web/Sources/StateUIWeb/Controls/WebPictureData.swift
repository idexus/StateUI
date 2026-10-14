// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIHost

/// A picture's bytes as a `data:` URL an `<img>` loads: their type read from their first bytes, the bytes in base64.
/// Design: docs/design/platforms/web/controls.md#pictures
enum WebPictureData {
    static func url(_ bytes: [UInt8]) -> String {
        "data:" + type(of: bytes) + ";base64," + Base64.encoded(bytes)
    }

    /// The picture's type, as its own first bytes say it: a PNG, a JPEG, a GIF, a WebP, else an SVG.
    static func type(of bytes: [UInt8]) -> String {
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "image/png" }
        if bytes.starts(with: [0xFF, 0xD8]) { return "image/jpeg" }
        if bytes.starts(with: [0x47, 0x49, 0x46]) { return "image/gif" }
        if bytes.count > 11, bytes[8..<12].elementsEqual([0x57, 0x45, 0x42, 0x50]) { return "image/webp" }
        return "image/svg+xml"
    }
}
