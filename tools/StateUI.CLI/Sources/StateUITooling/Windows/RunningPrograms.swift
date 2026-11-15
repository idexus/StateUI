// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
#if os(Windows)
import WinSDK
#endif

/// The programs running from a folder: what a build that writes the folder again stops first - those alone, so a
/// program of the same name running from another folder runs on.
/// Design: docs/design/tooling/winui-heads.md#a-running-head
enum RunningPrograms {
    /// Stops every process whose program stands in `folder`, waiting up to five seconds for each to end.
    static func stop(runningFrom folder: URL) {
        #if os(Windows)
        let prefix = folder.withUnsafeFileSystemRepresentation { String(cString: $0!) }
            .replacingOccurrences(of: "/", with: "\\").lowercased()
        let within = prefix.hasSuffix("\\") ? prefix : prefix + "\\"
        let snapshot = CreateToolhelp32Snapshot(DWORD(TH32CS_SNAPPROCESS), 0)
        guard let snapshot, snapshot != HANDLE(bitPattern: -1) else { return }
        defer { CloseHandle(snapshot) }
        var entry = PROCESSENTRY32W()
        entry.dwSize = DWORD(MemoryLayout<PROCESSENTRY32W>.size)
        var more = Process32FirstW(snapshot, &entry)
        while more {
            stop(entry.th32ProcessID, within: within)
            more = Process32NextW(snapshot, &entry)
        }
        #endif
    }

    #if os(Windows)
    /// Stops the process `id` where its program's path begins with `within`.
    private static func stop(_ id: DWORD, within: String) {
        let access = DWORD(PROCESS_QUERY_LIMITED_INFORMATION) | DWORD(PROCESS_TERMINATE) | DWORD(SYNCHRONIZE)
        guard let process = OpenProcess(access, false, id) else { return }
        defer { CloseHandle(process) }
        var size = DWORD(32_768)
        var name = [WCHAR](repeating: 0, count: Int(size))
        guard QueryFullProcessImageNameW(process, 0, &name, &size),
              String(decoding: name[..<Int(size)], as: UTF16.self).lowercased().hasPrefix(within)
        else { return }
        TerminateProcess(process, 1)
        WaitForSingleObject(process, 5_000)
    }
    #endif
}
