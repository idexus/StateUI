// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Synchronization
#if os(Windows)
import WinSDK
#elseif canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// The machine's one application build at a time: a lock the system holds on a file in the user's state folder,
/// which every `stateui` of every checkout takes before it builds an application - and the system lets go of when
/// the process holding it ends, however it ends.
/// Design: docs/design/tooling/builds.md#one-application-build-at-a-time
public struct BuildPermit: Sendable {
    /// The folder of the lock and of what says who holds it.
    public let folder: URL

    /// The permit of `folder`: the user's own state folder unless given.
    public init(folder: URL = BuildPermit.userFolder) {
        self.folder = folder
    }

    /// The user's state folder of the tool: `~/Library/Application Support/stateui` on macOS,
    /// `$XDG_STATE_HOME/stateui` (else `~/.local/state/stateui`) elsewhere, `%LOCALAPPDATA%\stateui` on Windows.
    public static var userFolder: URL {
        let environment = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser
        #if os(Windows)
        let base = environment["LOCALAPPDATA"].map { URL(fileURLWithPath: $0) } ?? home.appendingPathComponent("AppData/Local")
        #elseif os(macOS)
        let base = home.appendingPathComponent("Library/Application Support")
        #else
        let base = environment["XDG_STATE_HOME"].flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0) }
            ?? home.appendingPathComponent(".local/state")
        #endif
        return base.appendingPathComponent("stateui")
    }

    /// The permit, taken at once - `nil` while another holds it.
    public func take(for owner: String) throws -> Lease? {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        guard let lock = try Lock(file: folder.appendingPathComponent("build.lock")) else { return nil }
        try? Data(owner.utf8).write(to: ownerFile)
        return Lease(lock: lock, ownerFile: ownerFile)
    }

    /// The permit, waited for - `waiting` told who holds it, as the holder said, whenever that changes - until it is
    /// free or the wait is cancelled, which throws `CancellationError`.
    public func acquire(
        for owner: String, poll: Duration = .milliseconds(250), waiting: @Sendable (String) -> Void = { _ in }
    ) async throws -> Lease {
        var told: String?
        while true {
            if let lease = try take(for: owner) { return lease }
            if let holder, holder != told {
                waiting(holder)
                told = holder
            }
            try await Task.sleep(for: poll)
        }
    }

    /// Who holds the permit, as its holder said; `nil` where nobody said.
    public var holder: String? {
        (try? Data(contentsOf: ownerFile)).flatMap { String(data: $0, encoding: .utf8) }
    }

    private var ownerFile: URL { folder.appendingPathComponent("build.owner") }

    /// The permit held, until `release()` or the lease's end.
    public final class Lease: Sendable {
        private let lock: Mutex<Lock?>
        private let ownerFile: URL

        fileprivate init(lock: Lock, ownerFile: URL) {
            self.lock = Mutex(lock)
            self.ownerFile = ownerFile
        }

        /// Lets go of the permit; again, nothing.
        public func release() {
            guard let held = lock.withLock({ held in defer { held = nil }; return held }) else { return }
            try? FileManager.default.removeItem(at: ownerFile)
            held.close()
        }

        deinit { release() }
    }
}

/// An exclusive lock the system holds on an open file, let go of when the file is closed or the process ends.
struct Lock: Sendable {
    #if os(Windows)
    private let handle: UInt
    #else
    private let descriptor: Int32
    #endif

    /// The lock of `file`, taken at once; `nil` while another holds it.
    init?(file: URL) throws {
        #if os(Windows)
        let opened = file.path.withCString(encodedAs: UTF16.self) {
            CreateFileW($0, DWORD(GENERIC_READ) | DWORD(GENERIC_WRITE), DWORD(FILE_SHARE_READ) | DWORD(FILE_SHARE_WRITE), nil,
                        DWORD(OPEN_ALWAYS), DWORD(FILE_ATTRIBUTE_NORMAL), nil)
        }
        guard let opened, opened != INVALID_HANDLE_VALUE else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: file.path])
        }
        var overlapped = OVERLAPPED()
        guard LockFileEx(opened, DWORD(LOCKFILE_EXCLUSIVE_LOCK) | DWORD(LOCKFILE_FAIL_IMMEDIATELY), 0, 1, 0, &overlapped) else {
            CloseHandle(opened)
            return nil
        }
        handle = UInt(bitPattern: opened)
        #else
        let opened = open(file.path, O_RDWR | O_CREAT | O_CLOEXEC, 0o600)
        guard opened >= 0 else { throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: file.path]) }
        guard flock(opened, LOCK_EX | LOCK_NB) == 0 else {
            _ = closeDescriptor(opened)
            return nil
        }
        descriptor = opened
        #endif
    }

    /// Lets go of the lock.
    func close() {
        #if os(Windows)
        CloseHandle(HANDLE(bitPattern: handle))
        #else
        _ = closeDescriptor(descriptor)
        #endif
    }
}

#if !os(Windows)
private func closeDescriptor(_ descriptor: Int32) -> Int32 {
    #if canImport(Darwin)
    Darwin.close(descriptor)
    #else
    Glibc.close(descriptor)
    #endif
}
#endif
