// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUIToolingProtocol

extension HostFamily {
    /// The hosts whose heads run as programs of their machine's desktop - AppKit's, GTK's, WinUI's: started from the
    /// program built, followed until it ends, held by `lldb-dap` for a debugger, here or on another machine.
    public static let desktop: Set<HostFamily> = [.appkit, .gtk, .winui]
}

extension RunResult {
    /// The status the command that ran it ends with: a desktop head's program's own where it was not 0 - 128 and the
    /// signal that ended it - none for a head a device or a browser runs, followed until it is stopped.
    public var failureStatus: Int32? {
        guard HostFamily.desktop.contains(launched.build.host), let status = exitStatus, status != 0 else { return nil }
        return Int32(truncatingIfNeeded: status)
    }
}
