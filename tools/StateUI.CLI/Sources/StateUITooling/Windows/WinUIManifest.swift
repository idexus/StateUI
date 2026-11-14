// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// The manifest a self-contained WinUI application carries beside its executable, `<name>.exe.manifest`: every class
/// each Windows App SDK component's `package.appxfragment` declares, registered in the library that holds it, and the
/// application's own settings - per-monitor DPI, Windows 10 and later.
/// Design: docs/design/tooling/winui-heads.md#the-manifest
enum WinUIManifest {
    /// The proxy stubs a self-contained application has no singleton for.
    static let unregistered: Set<String> = ["PushNotificationsLongRunningTask.ProxyStub.dll", "Microsoft.Windows.Widgets.dll"]

    /// The manifest of the components whose fragments are `fragments`, in their order.
    static func text(fragments: [Data]) throws -> String {
        var lines = [
            "<?xml version='1.0' encoding='utf-8' standalone='yes'?>",
            "<assembly manifestVersion='1.0' xmlns='urn:schemas-microsoft-com:asm.v1' xmlns:asmv3='urn:schemas-microsoft-com:asm.v3' xmlns:winrtv1='urn:schemas-microsoft-com:winrt.v1'>",
        ]
        for fragment in fragments {
            for server in try Fragment.read(fragment) {
                switch server {
                case .inProcess(let path, let classes):
                    lines.append("  <asmv3:file name='\(path)'>")
                    lines += classes.map { "    <winrtv1:activatableClass name='\($0)' threadingModel='both'/>" }
                    lines.append("  </asmv3:file>")
                case .proxyStub(let path, let classID, let interfaces) where !unregistered.contains(path):
                    lines.append("  <asmv3:file name='\(path)'>")
                    lines.append("    <asmv3:comClass clsid='{\(classID)}'/>")
                    lines += interfaces.map { "    <asmv3:comInterfaceProxyStub name='\($0.name)' iid='{\($0.id)}'/>" }
                    lines.append("  </asmv3:file>")
                case .proxyStub:
                    continue
                }
            }
        }
        lines += [
            "  <asmv3:application>",
            "    <asmv3:windowsSettings>",
            "      <dpiAwareness xmlns='http://schemas.microsoft.com/SMI/2016/WindowsSettings'>PerMonitorV2</dpiAwareness>",
            "    </asmv3:windowsSettings>",
            "  </asmv3:application>",
            "  <compatibility xmlns='urn:schemas-microsoft-com:compatibility.v1'>",
            "    <application>",
            "      <supportedOS Id='{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}'/>",
            "    </application>",
            "  </compatibility>",
            "</assembly>",
        ]
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    /// What one fragment registers, in its order.
    enum Server: Equatable {
        case inProcess(path: String, classes: [String])
        case proxyStub(path: String, classID: String, interfaces: [(name: String, id: String)])

        static func == (a: Server, b: Server) -> Bool {
            switch (a, b) {
            case let (.inProcess(p, c), .inProcess(q, d)): p == q && c == d
            case let (.proxyStub(p, c, i), .proxyStub(q, d, j)): p == q && c == d && i.map(\.name) == j.map(\.name) && i.map(\.id) == j.map(\.id)
            default: false
            }
        }
    }

    /// A fragment's in-process servers and proxy stubs, in its order.
    private enum Fragment {
        static func read(_ data: Data) throws -> [Server] {
            let events: [XMLEvents.Event]
            do { events = try XMLEvents.read(data) } catch let refusal as XMLEvents.Refusal {
                throw ToolingError(.toolFailed, "A Windows App SDK fragment is not XML: \(refusal.reason).")
            }
            var servers: [Server] = []
            var (path, text, classes, classID) = ("", "", [String](), "")
            var interfaces: [(name: String, id: String)] = []
            for event in events {
                switch event {
                case .start(let name, let attributes):
                    text = ""
                    switch name {
                    case "InProcessServer": (path, classes) = ("", [])
                    case "ActivatableClass": attributes["ActivatableClassId"].map { classes.append($0) }
                    case "ProxyStub": (path, classID, interfaces) = ("", attributes["ClassId"] ?? "", [])
                    case "Interface": interfaces.append((attributes["Name"] ?? "", attributes["InterfaceId"] ?? ""))
                    default: break
                    }
                case .text(let string):
                    text += string
                case .end(let name):
                    switch name {
                    case "Path": path = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    case "InProcessServer": servers.append(.inProcess(path: path, classes: classes))
                    case "ProxyStub": servers.append(.proxyStub(path: path, classID: classID, interfaces: interfaces))
                    default: break
                    }
                }
            }
            return servers
        }
    }
}
