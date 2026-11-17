// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// How a debugger reaches each host's application, made where the tool readies it: the one place an editor's
/// debugger - VS Code's, Xcode's - learns the way from.
/// Design: docs/design/tooling/runs.md#how-a-debugger-reaches-it
enum DebugDescriptors {
    /// LLDB starting `program` in `working`: a head that runs as this machine's own program.
    static func program(_ program: URL, working: URL) -> DebugDescriptor {
        DebugDescriptor(kind: .lldb, request: .launch, programUri: FileURI.string(program), workingUri: FileURI.string(working))
    }

    /// LLDB attaching to `process` on a simulator, one of this Mac's, the application ending with the session.
    static func simulator(process: Int) -> DebugDescriptor {
        DebugDescriptor(kind: .lldb, request: .attach, process: process, terminateCommands: ["process kill"])
    }

    /// LLDB attaching to `process` through the device `device` names, its symbols read from `bundle` as built.
    static func device(_ device: String, process: Int, bundle: URL?) -> DebugDescriptor {
        let symbols = bundle.map { [$0, $0.appendingPathComponent("Frameworks")] } ?? []
        return DebugDescriptor(
            kind: .lldb, request: .attach, process: process,
            initCommands: symbols.map { "settings append target.exec-search-paths \($0.path)" },
            attachCommands: ["device select \(device)", "device process attach --pid \(process)"],
            terminateCommands: ["process kill"])
    }

    /// LLDB attaching to an Android head's `process` through the `lldb-server` readied in its sandbox at `socket`, on the
    /// device `serial` names, its libraries read unstripped from `symbols`.
    static func android(serial: String, socket: String, process: Int, symbols: URL?) -> DebugDescriptor {
        DebugDescriptor(
            kind: .lldb, request: .attach, process: process,
            initCommands: ["settings set plugin.jit-loader.gdb.enable off", "platform select remote-android",
                           "platform connect unix-abstract-connect://\(serial)/\(socket)"]
                + (symbols.map { ["settings append target.exec-search-paths \($0.path)"] } ?? []),
            attachCommands: ["process attach --pid \(process)",
                             "process handle SIGSEGV --pass true --stop false --notify false",
                             "process handle SIGBUS --pass true --stop false --notify false"])
    }

    /// A browser's debugger starting `browser` on the page at `url`, the page's sources read from `site`.
    static func page(_ url: String, browser: URL, site: URL) -> DebugDescriptor {
        DebugDescriptor(kind: .browser, request: .launch, programUri: FileURI.string(browser), url: url, sourceUri: FileURI.string(site))
    }
}
