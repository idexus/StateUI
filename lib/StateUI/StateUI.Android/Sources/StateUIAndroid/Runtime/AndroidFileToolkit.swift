// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// Android's part of the files the user opens and saves and of what the system launches (`HostActs.files`): the
/// system's document picker over the activity, a document read and written beside the UI thread, a view intent.
/// Each answers later, by the ticket it was handed.
/// Design: docs/design/platforms/android/runtime.md#files
@MainActor
final class AndroidFileToolkit: FileToolkit {
    /// The activity standing now, which a picker is shown over: the process's acts outlive each.
    private var context: jobject { AndroidRenderer.context }

    /// What hears each picker's documents, each document's bytes and each launch's answer, by ticket.
    private let dialogs = Numbered<(Result<[ChosenFile], ActFailure>) -> Void>()
    private let reads = Numbered<(Result<[UInt8], ActFailure>) -> Void>()
    private let launches = Numbered<(Bool) -> Void>()


    /// Lets go of the pickers still waiting: their questions were answered as dismissed.
    func forgetDialogs() {
        dialogs.removeAll()
    }

    func show(
        _ dialog: HostFileDialog, answered: @escaping (Result<[ChosenFile], ActFailure>) -> Void
    ) -> MountedElement? {
        guard let window = AndroidRenderer.window else { return nil }
        let ticket = dialogs.hold(answered)
        Java.frame {
            switch dialog.kind {
            case .open, .openSeveral:
                Java.callStatic(
                    JavaAPI.files, JavaAPI.openFiles, .object(context), .long(ticket),
                    .object(Java.strings(dialog.extensions)),
                    .bool(dialog.kind == .openSeveral))
            case .save:
                Java.callStatic(
                    JavaAPI.files, JavaAPI.saveFile, .object(context), .long(ticket),
                    .object(Java.string(dialog.name)), .object(dialog.savedExtension.flatMap(Java.string)),
                    .object(Java.bytes(dialog.contents)))
            }
        }
        return window
    }

    /// The picker under `ticket` closed: the documents chosen, by their addresses and names, or why it failed.
    func chose(ticket: Int64, addresses: [String], names: [String], failure: String?) {
        let files = zip(addresses, names).map { ChosenFile(address: $0, name: $1) }
        dialogs.take(ticket)?(failure.map { .failure(ActFailure($0)) } ?? .success(files))
    }

    func read(_ file: ChosenFile, atMost maximum: Int?, answered: @escaping (Result<[UInt8], ActFailure>) -> Void) {
        let ticket = reads.hold(answered)
        Java.frame {
            Java.callStatic(
                JavaAPI.files, JavaAPI.readFile, .object(context), .long(ticket),
                .object(Java.string(file.address)), .long(Int64(maximum ?? -1)))
        }
    }

    /// The document read under `ticket`: its bytes, or why they could not be read.
    func read(ticket: Int64, bytes: [UInt8], failure: String?) {
        reads.take(ticket)?(failure.map { .failure(ActFailure($0)) } ?? .success(bytes))
    }

    func launch(_ file: ChosenFile, answered: @escaping (Bool) -> Void) {
        launch(file.address, document: true, answered: answered)
    }

    func launch(address: String, answered: @escaping (Bool) -> Void) {
        launch(address, document: false, answered: answered)
    }

    private func launch(_ address: String, document: Bool, answered: @escaping (Bool) -> Void) {
        let ticket = launches.hold(answered)
        Java.frame {
            Java.callStatic(
                JavaAPI.files, JavaAPI.launch, .object(context), .long(ticket),
                .object(Java.string(address)), .bool(document))
        }
    }

    /// What was launched under `ticket` was taken by an application, or not.
    func launched(ticket: Int64, taken: Bool) {
        launches.take(ticket)?(taken)
    }
}
