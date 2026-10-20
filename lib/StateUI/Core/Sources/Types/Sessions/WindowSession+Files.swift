// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The dialogs that open and save files over a window, asked as acts like every question.
// Design: docs/design/core/acts.md#files

extension WindowSession {
    /// Asks the user for a file to open, over this window.
    ///
    ///     let page = FileType("HTML page", extensions: ["html", "htm"])
    ///     if let file = try await window.openFile(types: [page]) {
    ///         let bytes = try await file.read()
    ///     }
    ///
    /// - Parameter types: the kinds of file it shows; none for any file.
    /// - Returns: the file chosen, or nil where the dialog was cancelled.
    /// - Throws: `WindowError` for a window no longer open, and `StateUIError` when there is no window to show it.
    public func openFile(types: [FileType] = []) async throws -> ChosenFile? {
        let (scene, window) = try address
        return try await stateUICall(ApplicationContract.openFiles, scene, window, types, false).first
    }

    /// Asks the user for files to open, as many as they choose, over this window.
    ///
    ///     for file in try await window.openFiles(types: [picture]) {
    ///         pictures.append(try await file.read())
    ///     }
    ///
    /// - Parameter types: the kinds of file it shows; none for any file.
    /// - Returns: the files chosen, in the dialog's order; none where it was
    ///   cancelled.
    /// - Throws: `WindowError` for a window no longer open, and `StateUIError` when there is no window to show it.
    public func openFiles(types: [FileType] = []) async throws -> [ChosenFile] {
        let (scene, window) = try address
        return try await stateUICall(ApplicationContract.openFiles, scene, window, types, true)
    }

    /// Asks the user where to save `contents`, over this window, and writes them there.
    ///
    ///     let page = FileType("HTML page", extensions: ["html"])
    ///     if let saved = try await window.saveFile(
    ///         Array(report.utf8), name: "Report", types: [page]) {
    ///         try await saved.launch()
    ///     }
    ///
    /// The contents go first, as some platforms hand a ready file over
    /// rather than ask for a place.
    ///
    /// - Parameters:
    ///   - contents: what the file holds.
    ///   - name: the name it suggests; the first type's extension is added
    ///     where it ends in none of theirs.
    ///   - types: the kinds of file it offers, the first chosen; none for any.
    /// - Returns: the file saved, or nil where the dialog was cancelled.
    /// - Throws: `WindowError` for a window no longer open, `StateUIError` when there is no window to show it, or
    ///   where the platform cannot write there.
    @discardableResult
    public func saveFile(_ contents: [UInt8], name: String, types: [FileType] = []) async throws -> ChosenFile? {
        let (scene, window) = try address
        return try await stateUICall(ApplicationContract.saveFile, scene, window, contents, name, types)
    }
}
