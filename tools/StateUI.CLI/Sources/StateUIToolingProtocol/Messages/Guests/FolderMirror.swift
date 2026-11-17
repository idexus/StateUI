// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What `folder/mirror` makes of a folder of this machine: `targetPath` holding what `sourcePath` holds - in a guest,
/// a Mac's folder it shares copied to its own disk.
public struct FolderMirrorRequest: Codable, Equatable, Sendable {
    /// The folder copied from, as this machine writes a path: a shared folder's in a guest.
    public var sourcePath: String
    /// The folder copied to, as this machine writes a path.
    public var targetPath: String
    /// The files copied, each by its path from `sourcePath` written with `/` - those git tracks and would track; nil
    /// for every file there.
    public var files: [String]?

    /// `sourcePath` copied to `targetPath`, `files` alone where given.
    public init(sourcePath: String, targetPath: String, files: [String]? = nil) {
        self.sourcePath = sourcePath
        self.targetPath = targetPath
        self.files = files
    }
}

/// What a mirror did: the files it copied, those it removed from the target as gone from the source, and those it left
/// as they were.
public struct FolderMirrorResult: Codable, Equatable, Sendable {
    public var copied: Int
    public var removed: Int
    public var unchanged: Int

    /// A mirror that copied `copied` files, removed `removed` and left `unchanged`.
    public init(copied: Int, removed: Int, unchanged: Int) {
        self.copied = copied
        self.removed = removed
        self.unchanged = unchanged
    }
}
