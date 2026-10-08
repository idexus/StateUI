// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// GTK's part of the files the user opens and saves and of what the desktop launches (`HostActs.files`): GTK's file
/// dialog - the desktop's own through its portal where it has one - over the window the user is in, a file read and
/// written by GIO beside the UI thread, GTK's launchers. A test holds the dialog and the launches back.
/// Design: docs/design/platforms/gtk/runtime.md#files
@MainActor
final class GTKFileToolkit: FileToolkit {
    private unowned let renderer: GTKRenderer

    /// Whether a dialog and a launch are only held, never shown or handed to the desktop: a test's.
    var holdsForTesting = false

    /// The dialog a test holds, with what hears its answer.
    private(set) var held: (dialog: HostFileDialog, answered: (Result<[ChosenFile], ActFailure>) -> Void)?

    /// What the host handed the desktop to launch, in order: an address as written, a file by its path.
    private(set) var launchedForTesting: [String] = []

    init(renderer: GTKRenderer) {
        self.renderer = renderer
    }

    func show(_ dialog: HostFileDialog, answered: @escaping (Result<[ChosenFile], ActFailure>) -> Void) -> Bool {
        guard let window = renderer.userWindow else { return false }
        if holdsForTesting {
            held = (dialog, answered)
            return true
        }
        let parent = window.widget.of(GtkWindow.self)
        Task { @MainActor in
            let chosen = await Self.pick(dialog, over: parent)
            guard dialog.kind == .save, case .success(let files) = chosen, let place = files.first else {
                return answered(chosen)
            }
            answered(await Self.write(dialog.contents, to: place.address).map { files })
        }
        return true
    }

    /// Answers the dialog held as the user does, by the files at `paths` - none cancels it: a save's contents written
    /// there first.
    func chooseForTesting(_ paths: [String]) {
        guard let (dialog, answered) = held else { return }
        held = nil
        let files = paths.map(Self.file(at:))
        guard dialog.kind == .save, let place = files.first else { return answered(.success(files)) }
        Task { @MainActor in answered(await Self.write(dialog.contents, to: place.address).map { files }) }
    }

    func read(_ file: ChosenFile, atMost maximum: Int?, answered: @escaping (Result<[UInt8], ActFailure>) -> Void) {
        Task { @MainActor in answered(await Self.contents(of: file.address, atMost: maximum)) }
    }

    func launch(_ file: ChosenFile, answered: @escaping (Bool) -> Void) {
        launchedForTesting.append(file.address)
        launch(answered) { parent, done, data in
            let gfile = g_file_new_for_path(file.address)
            let launcher = gtk_file_launcher_new(gfile)
            g_object_unref(UnsafeMutableRawPointer(gfile))
            gtk_file_launcher_launch(launcher, parent, nil, done, data)
        } finish: { source, result in
            gtk_file_launcher_launch_finish(OpaquePointer(source), result, nil) != 0
        }
    }

    func launch(address: String, answered: @escaping (Bool) -> Void) {
        guard g_uri_peek_scheme(address) != nil else {
            Task { @MainActor in answered(false) }
            return
        }
        launchedForTesting.append(address)
        launch(answered) { parent, done, data in
            gtk_uri_launcher_launch(gtk_uri_launcher_new(address), parent, nil, done, data)
        } finish: { source, result in
            gtk_uri_launcher_launch_finish(OpaquePointer(source), result, nil) != 0
        }
    }

    /// Hands what `start` launches to the desktop over the user's window; `answered` hears whether an application
    /// took it - true where a test holds it back - never in the turn that asked.
    private func launch(
        _ answered: @escaping (Bool) -> Void,
        start: (UnsafeMutablePointer<GtkWindow>?, GAsyncReadyCallback, gpointer) -> Void,
        finish: @escaping @Sendable (UnsafeMutablePointer<GObject>?, OpaquePointer?) -> Bool
    ) {
        if holdsForTesting {
            Task { @MainActor in answered(true) }
            return
        }
        let pending = Pending { source, result in
            let taken = finish(source, result)
            g_object_unref(UnsafeMutableRawPointer(source))
            MainActor.assumeIsolated { answered(taken) }
        }
        start(renderer.userWindow?.widget.of(GtkWindow.self), Pending.finished, Unmanaged.passRetained(pending).toOpaque())
    }

    // MARK: - GIO

    /// What hears an asynchronous call of GIO's finish, by the data handed it.
    private final class Pending: @unchecked Sendable {
        let finished: (UnsafeMutablePointer<GObject>?, OpaquePointer?) -> Void

        /// The most bytes a partial load reads on to.
        var maximum = Int.max

        init(_ finished: @escaping (UnsafeMutablePointer<GObject>?, OpaquePointer?) -> Void) {
            self.finished = finished
        }

        static let finished: GAsyncReadyCallback = { source, result, data in
            Unmanaged<Pending>.fromOpaque(data!).takeRetainedValue().finished(source, result)
        }

        /// Whether a partial load reads another block: only while it holds fewer bytes than the most.
        static let readsMore: GFileReadMoreCallback = { _, size, data in
            Int(size) < Unmanaged<Pending>.fromOpaque(data!).takeUnretainedValue().maximum ? 1 : 0
        }
    }

    /// The file at `path`, by its name.
    private static func file(at path: String) -> ChosenFile {
        let base = g_path_get_basename(path)
        defer { g_free(base) }
        return ChosenFile(address: path, name: base.map { String(cString: $0) } ?? path)
    }

    /// The files GIO hands back as `files`, each let go of: by path, the ones with none left out.
    private static func chosen(_ files: [OpaquePointer]) -> [ChosenFile] {
        files.compactMap { gfile in
            defer { g_object_unref(UnsafeMutableRawPointer(gfile)) }
            guard let path = g_file_get_path(gfile) else { return nil }
            defer { g_free(path) }
            return file(at: String(cString: path))
        }
    }

    /// Why GIO failed, `error` let go of; nil where the user dismissed or cancelled the dialog.
    private static func failure(_ error: UnsafeMutablePointer<GError>?) -> ActFailure? {
        guard let error else { return nil }
        defer { g_error_free(error) }
        let dismissed = error.pointee.domain == gtk_dialog_error_quark()
            && [GTK_DIALOG_ERROR_DISMISSED.rawValue, GTK_DIALOG_ERROR_CANCELLED.rawValue].contains(UInt32(error.pointee.code))
        return dismissed ? nil : ActFailure(error.pointee.message.map { String(cString: $0) } ?? "the file dialog failed")
    }

    /// Shows GTK's file dialog for `dialog` over `parent`; the files chosen, none where it was dismissed.
    private static func pick(
        _ dialog: HostFileDialog, over parent: UnsafeMutablePointer<GtkWindow>
    ) async -> Result<[ChosenFile], ActFailure> {
        let fileDialog = gtk_file_dialog_new()!
        offer(dialog, on: fileDialog)
        let kind = dialog.kind
        return await withCheckedContinuation { done in
            let pending = Pending { source, result in
                var error: UnsafeMutablePointer<GError>?
                var files: [OpaquePointer] = []
                let shown = OpaquePointer(source)
                switch kind {
                case .open:
                    if let file = gtk_file_dialog_open_finish(shown, result, &error) { files = [file] }
                case .openSeveral:
                    if let list = gtk_file_dialog_open_multiple_finish(shown, result, &error) {
                        for index in 0..<g_list_model_get_n_items(list) {
                            if let item = g_list_model_get_item(list, index) { files.append(OpaquePointer(item)) }
                        }
                        g_object_unref(UnsafeMutableRawPointer(list))
                    }
                case .save:
                    if let file = gtk_file_dialog_save_finish(shown, result, &error) { files = [file] }
                }
                g_object_unref(UnsafeMutableRawPointer(shown))
                let why = failure(error)
                done.resume(returning: why.map { .failure($0) } ?? .success(chosen(files)))
            }
            let data = Unmanaged.passRetained(pending).toOpaque()
            switch kind {
            case .open: gtk_file_dialog_open(fileDialog, parent, nil, Pending.finished, data)
            case .openSeveral: gtk_file_dialog_open_multiple(fileDialog, parent, nil, Pending.finished, data)
            case .save: gtk_file_dialog_save(fileDialog, parent, nil, Pending.finished, data)
            }
        }
    }

    /// Sets the kinds `dialog` offers and the name it suggests: a dialog that opens shows every kind's files under
    /// one filter, one that saves offers each kind, the first chosen.
    private static func offer(_ dialog: HostFileDialog, on fileDialog: OpaquePointer) {
        if dialog.kind == .save, !dialog.name.isEmpty { gtk_file_dialog_set_initial_name(fileDialog, dialog.name) }
        guard !dialog.types.isEmpty else { return }
        let kinds: [(caption: String, extensions: [String])] = dialog.kind == .save
            ? dialog.types.map { ($0.caption, $0.extensions) }
            : [(dialog.types.map(\.caption).joined(separator: ", "), dialog.extensions)]
        let filters = g_list_store_new(gtk_file_filter_get_type())
        for kind in kinds {
            let filter = gtk_file_filter_new()
            gtk_file_filter_set_name(filter, kind.caption)
            for suffix in kind.extensions { gtk_file_filter_add_suffix(filter, suffix) }
            g_list_store_append(filters, UnsafeMutableRawPointer(filter))
            g_object_unref(UnsafeMutableRawPointer(filter))
        }
        gtk_file_dialog_set_filters(fileDialog, filters)
        g_object_unref(UnsafeMutableRawPointer(filters))
    }

    /// Writes `contents` to the file at `path`, replacing what stood there, beside the UI thread.
    private static func write(_ contents: [UInt8], to path: String) async -> Result<Void, ActFailure> {
        await withCheckedContinuation { done in
            let gfile = g_file_new_for_path(path)
            let bytes = contents.withUnsafeBytes { g_bytes_new($0.baseAddress, gsize($0.count)) }
            let pending = Pending { source, result in
                var error: UnsafeMutablePointer<GError>?
                _ = g_file_replace_contents_finish(OpaquePointer(source), result, nil, &error)
                g_object_unref(UnsafeMutableRawPointer(source))
                let why = error.map { error in
                    defer { g_error_free(error) }
                    return ActFailure(error.pointee.message.map { String(cString: $0) } ?? "the file could not be written")
                }
                done.resume(returning: why.map { .failure($0) } ?? .success(()))
            }
            g_file_replace_contents_bytes_async(
                gfile, bytes, nil, 0, STATEUI_FILE_CREATE_NONE, nil, Pending.finished,
                Unmanaged.passRetained(pending).toOpaque())
            g_bytes_unref(bytes)
        }
    }

    /// The contents of the file at `path`, read beside the UI thread.
    /// The file's bytes, or its first `maximum`: GIO reads block by block and stops once it holds as many, the
    /// last block's rest cut off.
    private static func contents(of path: String, atMost maximum: Int?) async -> Result<[UInt8], ActFailure> {
        await withCheckedContinuation { done in
            let gfile = g_file_new_for_path(path)
            let pending = Pending { source, result in
                var contents: UnsafeMutablePointer<CChar>?
                var length: gsize = 0
                var error: UnsafeMutablePointer<GError>?
                let read = maximum == nil
                    ? g_file_load_contents_finish(OpaquePointer(source), result, &contents, &length, nil, &error)
                    : g_file_load_partial_contents_finish(OpaquePointer(source), result, &contents, &length, nil, &error)
                g_object_unref(UnsafeMutableRawPointer(source))
                guard read != 0, let contents else {
                    let why = error.map { String(cString: $0.pointee.message) } ?? "the file could not be read"
                    if let error { g_error_free(error) }
                    return done.resume(returning: .failure(ActFailure(why)))
                }
                let count = min(Int(length), maximum ?? Int.max)
                let bytes = Array(UnsafeRawBufferPointer(start: UnsafeRawPointer(contents), count: count))
                g_free(contents)
                done.resume(returning: .success(bytes))
            }
            let data = Unmanaged.passRetained(pending).toOpaque()
            if let maximum {
                pending.maximum = maximum
                g_file_load_partial_contents_async(gfile, nil, Pending.readsMore, Pending.finished, data)
            } else {
                g_file_load_contents_async(gfile, nil, Pending.finished, data)
            }
        }
    }
}
