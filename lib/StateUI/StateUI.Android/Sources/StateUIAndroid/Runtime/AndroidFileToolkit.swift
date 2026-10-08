// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Android's part of the files the user opens and saves and of what the system launches (`HostActs.files`): the
/// system's document picker over the activity, a document read and written beside the UI thread, a view intent.
/// Each answers later, by the ticket it was handed.
/// Design: docs/design/platforms/android/runtime.md#files
@MainActor
final class AndroidFileToolkit: FileToolkit {
    private let context: JavaObject

    /// What hears each picker's documents, each document's bytes and each launch's answer, by ticket.
    private var dialogs: [Int64: (Result<[ChosenFile], ActFailure>) -> Void] = [:]
    private var reads: [Int64: (Result<[UInt8], ActFailure>) -> Void] = [:]
    private var launches: [Int64: (Bool) -> Void] = [:]

    /// One number across the process, so an answer arriving after its renderer has gone answers nothing of another's.
    private static var nextTicket: Int64 = 1

    init(context: JavaObject) {
        self.context = context
    }

    private static func ticket() -> Int64 {
        defer { nextTicket += 1 }
        return nextTicket
    }

    func show(_ dialog: HostFileDialog, answered: @escaping (Result<[ChosenFile], ActFailure>) -> Void) -> Bool {
        let ticket = Self.ticket()
        dialogs[ticket] = answered
        Java.frame {
            switch dialog.kind {
            case .open, .openSeveral:
                Java.callStatic(
                    JavaAPI.files, JavaAPI.openFiles, .object(context.reference), .long(ticket),
                    .object(Java.array(of: JavaAPI.string, dialog.extensions.map(Java.string))),
                    .bool(dialog.kind == .openSeveral))
            case .save:
                Java.callStatic(
                    JavaAPI.files, JavaAPI.saveFile, .object(context.reference), .long(ticket),
                    .object(Java.string(dialog.name)), .object(Self.savedExtension(dialog).flatMap(Java.string)),
                    .object(Java.bytes(dialog.contents)))
            }
        }
        return true
    }

    /// The extension a save's type is read from: its name's, else its first kind's.
    private static func savedExtension(_ dialog: HostFileDialog) -> String? {
        if let dot = dialog.name.lastIndex(of: "."), dialog.name.index(after: dot) < dialog.name.endIndex {
            return String(dialog.name[dialog.name.index(after: dot)...]).lowercased()
        }
        return dialog.extensions.first
    }

    /// The picker under `ticket` closed: the documents chosen, by their addresses and names, or why it failed.
    func chose(ticket: Int64, addresses: [String], names: [String], failure: String?) {
        let files = zip(addresses, names).map { ChosenFile(address: $0, name: $1) }
        dialogs.removeValue(forKey: ticket)?(failure.map { .failure(ActFailure($0)) } ?? .success(files))
    }

    func read(_ file: ChosenFile, atMost maximum: Int?, answered: @escaping (Result<[UInt8], ActFailure>) -> Void) {
        let ticket = Self.ticket()
        reads[ticket] = answered
        Java.frame {
            Java.callStatic(
                JavaAPI.files, JavaAPI.readFile, .object(context.reference), .long(ticket),
                .object(Java.string(file.address)), .long(Int64(maximum ?? -1)))
        }
    }

    /// The document read under `ticket`: its bytes, or why they could not be read.
    func read(ticket: Int64, bytes: [UInt8], failure: String?) {
        reads.removeValue(forKey: ticket)?(failure.map { .failure(ActFailure($0)) } ?? .success(bytes))
    }

    func launch(_ file: ChosenFile, answered: @escaping (Bool) -> Void) {
        launch(file.address, document: true, answered: answered)
    }

    func launch(address: String, answered: @escaping (Bool) -> Void) {
        launch(address, document: false, answered: answered)
    }

    private func launch(_ address: String, document: Bool, answered: @escaping (Bool) -> Void) {
        let ticket = Self.ticket()
        launches[ticket] = answered
        Java.frame {
            Java.callStatic(
                JavaAPI.files, JavaAPI.launch, .object(context.reference), .long(ticket),
                .object(Java.string(address)), .bool(document))
        }
    }

    /// What was launched under `ticket` was taken by an application, or not.
    func launched(ticket: Int64, taken: Bool) {
        launches.removeValue(forKey: ticket)?(taken)
    }
}
