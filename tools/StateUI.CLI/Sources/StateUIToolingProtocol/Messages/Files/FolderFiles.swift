// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A file of a folder: its path from the folder, written with `/`, its size, and the time it last changed, in
/// seconds since 1970.
public struct FileEntry: Codable, Equatable, Sendable {
    public var path: String
    public var size: Int
    public var modified: Double

    /// The file at `path`, `size` bytes, changed at `modified`.
    public init(path: String, size: Int, modified: Double) {
        self.path = path
        self.size = size
        self.modified = modified
    }
}

/// The folder whose files are asked for - `folder/survey`'s parameters: a path of the machine that answers.
public struct FolderSurveyRequest: Codable, Equatable, Sendable {
    public var root: String

    /// The files of `root`.
    public init(root: String) {
        self.root = root
    }
}

/// The files a folder holds, but for what a machine makes where it builds - `folder/survey`'s result; none where the
/// folder stands not.
public struct FolderSurvey: Codable, Equatable, Sendable {
    public var files: [FileEntry]

    /// A folder holding `files`.
    public init(files: [FileEntry]) {
        self.files = files
    }
}

/// A piece of a file: its bytes from `offset`, in base64, beside the whole file's size and time - written where it
/// goes, read where it comes from.
public struct FilePiece: Codable, Equatable, Sendable {
    public var path: String
    public var offset: Int
    public var size: Int
    public var modified: Double
    public var data: String

    /// `data` of the file at `path` from `offset`, the file `size` bytes and changed at `modified`.
    public init(path: String, offset: Int, size: Int, modified: Double, data: String) {
        self.path = path
        self.offset = offset
        self.size = size
        self.modified = modified
        self.data = data
    }
}

/// Pieces written into a folder - `files/write`'s parameters: each file's first piece starts it anew, its last makes
/// it stand with its time.
public struct FilesWriteRequest: Codable, Equatable, Sendable {
    public var root: String
    public var pieces: [FilePiece]

    /// `pieces` written under `root`.
    public init(root: String, pieces: [FilePiece]) {
        self.root = root
        self.pieces = pieces
    }
}

/// How many files a write completed - `files/write`'s result.
public struct FilesWritten: Codable, Equatable, Sendable {
    public var completed: Int

    /// `completed` files made whole.
    public init(completed: Int) {
        self.completed = completed
    }
}

/// A piece of a file asked for - `file/read`'s parameters: at most `length` bytes from `offset`.
public struct FileReadRequest: Codable, Equatable, Sendable {
    public var root: String
    public var path: String
    public var offset: Int
    public var length: Int

    /// At most `length` bytes of `path` under `root`, from `offset`.
    public init(root: String, path: String, offset: Int, length: Int) {
        self.root = root
        self.path = path
        self.offset = offset
        self.length = length
    }
}

/// Files taken away from a folder - `files/remove`'s parameters.
public struct FilesRemoveRequest: Codable, Equatable, Sendable {
    public var root: String
    public var paths: [String]

    /// `paths` under `root`, removed.
    public init(root: String, paths: [String]) {
        self.root = root
        self.paths = paths
    }
}

/// How many files were removed - `files/remove`'s result.
public struct FilesRemoved: Codable, Equatable, Sendable {
    public var removed: Int

    /// `removed` files taken away.
    public init(removed: Int) {
        self.removed = removed
    }
}
