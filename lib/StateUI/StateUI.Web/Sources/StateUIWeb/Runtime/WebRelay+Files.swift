// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIWeb

/// The files the user opens and saves, and what the browser launches, in Swift's words: a file is the number the
/// relay keeps it under, and each act answers a listener once.
/// Design: docs/design/platforms/web/runtime.md#files
extension WebRelay {
    /// Asks for one file to open, or `several`, of `extensions` - any where there are none.
    static func openFiles(several: Bool, extensions: [String], _ listener: Int32) {
        utf8(extensions.map { "." + $0 }.joined(separator: ",")) {
            stateui_web_open_files(several ? 1 : 0, $0, $1, listener)
        }
    }

    /// Asks for a place to save `contents` in, `name` suggested and `kinds` offered.
    static func saveFile(_ contents: [UInt8], name: String, kinds: [FileType], _ listener: Int32) {
        let offered = kinds.map { "\($0.caption)\u{1F}\($0.extensions.joined(separator: " "))" }
            .joined(separator: "\u{1E}")
        utf8(name) { name, nameLength in
            utf8(offered) { offered, offeredLength in
                contents.withUnsafeBufferPointer {
                    stateui_web_save_file(
                        name, nameLength, offered, offeredLength, $0.baseAddress, Int32($0.count), listener)
                }
            }
        }
    }

    /// Reads the file `number` whole; its listener reads `fileBytes`.
    static func readFile(_ number: Int32, _ listener: Int32) {
        stateui_web_read_file(number, listener)
    }

    /// Opens the file `number` in a window of its own.
    static func launchFile(_ number: Int32, _ listener: Int32) {
        stateui_web_launch_file(number, listener)
    }

    /// Opens `address` in a window of its own.
    static func launchAddress(_ address: String, _ listener: Int32) {
        utf8(address) { stateui_web_launch_address($0, $1, listener) }
    }

    /// Whether the file's act being heard kept its promise - a dialog answered, a file read, a window opened.
    static var fileKept: Bool { stateui_web_event_number(0) != 0 }

    /// The files a dialog being heard answered, each its number and its name; none where the user cancelled.
    static var filesChosen: [(number: Int32, name: String)] {
        files(in: fileWords)
    }

    /// The files `words` say, as the relay says chosen files: each its number, then its name.
    static func files(in words: String) -> [(number: Int32, name: String)] {
        let parts = words.split(separator: "\u{1F}", omittingEmptySubsequences: false).map(String.init)
        return stride(from: 0, to: parts.count - 1, by: 2).compactMap { index in
            Int32(parts[index]).map { ($0, parts[index + 1]) }
        }
    }

    /// What a file's act being heard answered in words: why it broke.
    static var fileWords: String { copyRead(length: stateui_web_file_words()) }

    /// The bytes of the file being heard as read.
    static var fileBytes: [UInt8] {
        let length = Int(stateui_web_event_number(1))
        guard length > 0 else { return [] }
        return [UInt8](unsafeUninitializedCapacity: length) { buffer, count in
            buffer.withMemoryRebound(to: CChar.self) { stateui_web_copy_read($0.baseAddress) }
            count = length
        }
    }
}
