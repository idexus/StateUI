// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
import StateUIToolingProtocol

/// A program started to outlive the tool - an emulator the machine keeps, as it keeps a booted simulator: in a
/// session of its own, which a terminal's interrupt does not reach, its streams on the null device.
/// Design: docs/design/tooling/processes.md#a-program-the-machine-keeps
enum DetachedProcess {
    /// Starts `executable` with `arguments`.
    ///
    /// - Throws: ``ToolingError`` `TOOL_FAILED` where it cannot start.
    static func start(_ executable: String, _ arguments: [String]) throws {
        #if os(Windows)
        throw ToolingError(.toolFailed, "\(executable) is started apart from the tool on macOS and Linux.")
        #else
        #if canImport(Darwin)
        var actions: posix_spawn_file_actions_t?
        var attributes: posix_spawnattr_t?
        #else
        var actions = posix_spawn_file_actions_t()
        var attributes = posix_spawnattr_t()
        #endif
        posix_spawn_file_actions_init(&actions)
        posix_spawnattr_init(&attributes)
        defer {
            posix_spawn_file_actions_destroy(&actions)
            posix_spawnattr_destroy(&attributes)
        }
        for descriptor: Int32 in [0, 1, 2] {
            posix_spawn_file_actions_addopen(&actions, descriptor, "/dev/null", descriptor == 0 ? O_RDONLY : O_WRONLY, 0)
        }
        #if canImport(Darwin)
        let ownSession = Int16(POSIX_SPAWN_SETSID)
        #else
        // glibc's spawn.h gives it only to GNU sources.
        let ownSession: Int16 = 0x80
        #endif
        posix_spawnattr_setflags(&attributes, ownSession)
        let argv = ([executable] + arguments).map { strdup($0) } + [nil]
        defer { argv.forEach { free($0) } }
        var process = pid_t()
        let result = posix_spawn(&process, executable, &actions, &attributes, argv, environ)
        guard result == 0 else {
            throw ToolingError(.toolFailed, "\(executable) did not start: \(String(cString: strerror(result))).")
        }
        #endif
    }
}
