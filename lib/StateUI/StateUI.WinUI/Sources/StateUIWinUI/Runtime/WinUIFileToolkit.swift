// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// WinUI's part of the files the user opens and saves and of what Windows launches (`HostActs.files`): Windows' own
/// file dialogs over the window the user is in, a file read and written beside the UI thread, `Launcher`. Each answer
/// comes back by its ticket.
/// Design: docs/design/platforms/winui/runtime.md#files
@MainActor
final class WinUIFileToolkit: FileToolkit {
    private unowned let renderer: WinUIRenderer

    /// What hears each dialog's files, each file's bytes and each launch's answer, by the ticket the relay hands back.
    private var dialogs: [Int64: (Result<[ChosenFile], ActFailure>) -> Void] = [:]
    private var reads: [Int64: (Result<[UInt8], ActFailure>) -> Void] = [:]
    private var launches: [Int64: (Bool) -> Void] = [:]

    /// The next ticket: one number across the process, so an answer arriving after its renderer has gone answers
    /// nothing of another's.
    private static var nextTicket: Int64 = 1

    init(renderer: WinUIRenderer) {
        self.renderer = renderer
    }

    private static func ticket() -> Int64 {
        defer { nextTicket += 1 }
        return nextTicket
    }

    func show(_ dialog: HostFileDialog, answered: @escaping (Result<[ChosenFile], ActFailure>) -> Void) -> Bool {
        guard let window = renderer.userWindow else { return false }
        let ticket = Self.ticket()
        dialogs[ticket] = answered
        let kind: Int32 = switch dialog.kind {
        case .open: 0
        case .openSeveral: 1
        case .save: 2
        }
        let captions = dialog.types.map(\.caption)
        let counts = dialog.types.map { Int32($0.extensions.count) }
        // The captions, then every kind's extensions in turn, then the name a save suggests.
        WinUIStrings.withCStrings(captions + dialog.types.flatMap(\.extensions) + [dialog.name]) { strings in
            let named = Array(strings.prefix(captions.count))
            let extensions = Array(strings.dropFirst(captions.count).dropLast())
            named.withUnsafeBufferPointer { named in
                extensions.withUnsafeBufferPointer { extensions in
                    counts.withUnsafeBufferPointer { counts in
                        dialog.contents.withUnsafeBufferPointer { contents in
                            var relayed = StateUIFileDialog(
                                kind: kind, typeCount: Int32(captions.count), captions: named.baseAddress,
                                extensionCounts: counts.baseAddress, extensions: extensions.baseAddress,
                                name: strings.last ?? nil, contents: contents.baseAddress,
                                length: Int64(contents.count))
                            stateui_winui_show_file_dialog(window.handle, ticket, &relayed)
                        }
                    }
                }
            }
        }
        return true
    }

    /// The dialog under `ticket` closed: the files chosen, by their paths and names, or why it failed.
    func chose(ticket: Int64, files: [ChosenFile], failure: String?) {
        dialogs.removeValue(forKey: ticket)?(failure.map { .failure(ActFailure($0)) } ?? .success(files))
    }

    func read(_ file: ChosenFile, answered: @escaping (Result<[UInt8], ActFailure>) -> Void) {
        let ticket = Self.ticket()
        reads[ticket] = answered
        stateui_winui_read_file(ticket, file.address)
    }

    /// The file read under `ticket`: its bytes, or why they could not be read.
    func read(ticket: Int64, bytes: [UInt8], failure: String?) {
        reads.removeValue(forKey: ticket)?(failure.map { .failure(ActFailure($0)) } ?? .success(bytes))
    }

    func launch(_ file: ChosenFile, answered: @escaping (Bool) -> Void) {
        let ticket = Self.ticket()
        launches[ticket] = answered
        stateui_winui_launch(ticket, file.address, true)
    }

    func launch(address: String, answered: @escaping (Bool) -> Void) {
        let ticket = Self.ticket()
        launches[ticket] = answered
        stateui_winui_launch(ticket, address, false)
    }

    /// What was launched under `ticket` was taken by an application, or not.
    func launched(ticket: Int64, taken: Bool) {
        launches.removeValue(forKey: ticket)?(taken)
    }
}
