// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

extension Doctor {
    /// What the WinUI host needs on Windows.
    func windowsChecks() -> [Check] {
        let environment = ProcessInfo.processInfo.environment
        let programs = URL(fileURLWithPath: environment["ProgramFiles(x86)"] ?? "C:\\Program Files (x86)")
        #if arch(arm64)
        let cTools = "Microsoft.VisualStudio.Component.VC.Tools.ARM64"
        #else
        let cTools = "Microsoft.VisualStudio.Component.VC.Tools.x86.x64"
        #endif
        let swift = ToolResolver(environment: environment).swift
        return [
            Check(
                component: "Swift 6.4 from swift.org", neededBy: "WinUI", hosts: [.winui],
                advice: "Install Swift 6.4 from https://www.swift.org/install/windows.") {
                    let text = await ToolOutput.text(swift, ["--version"]) ?? ""
                    return Versions.isSwiftOrgBuild(text) ? Self.served(Versions.swiftRelease(in: text), "6.4") : .missing
                },
            Check(
                component: "Visual Studio 2026 with the C++ tools for this machine", neededBy: "WinUI", hosts: [.winui],
                advice: "Install Visual Studio 2026 with \"Desktop development with C++\" (\(cTools)).") {
                    let vswhere = programs.appendingPathComponent("Microsoft Visual Studio/Installer/vswhere.exe")
                    let version = await ToolOutput.text(
                        .path(vswhere.path),
                        ["-latest", "-products", "*", "-requires", cTools, "-property", "installationVersion"])
                    return Self.served(version.flatMap { Versions.first(in: $0) }, "18")
                },
            Check(
                component: "the WebView2 runtime", neededBy: "WinUI's web view (lib/Backends/WebView.WinUI)", hosts: [],
                advice: "Install the Evergreen WebView2 Runtime from https://developer.microsoft.com/microsoft-edge/webview2"
                    + " - Windows 11 has it.") {
                    let application = programs.appendingPathComponent("Microsoft/EdgeWebView/Application")
                    let version = ((try? FileManager.default.contentsOfDirectory(atPath: application.path)) ?? [])
                        .filter { $0.first?.isNumber == true && $0.contains(".") }
                        .sorted { Versions.compare($0, $1) < 0 }.last
                    return Self.present(version.map { application.appendingPathComponent($0).path })
                },
            Check(
                component: "the Windows SDK 10.0.26100", neededBy: "WinUI", hosts: [.winui],
                advice: "Install the Windows 11 SDK (10.0.26100) with the Visual Studio Installer.") {
                    let include = programs.appendingPathComponent("Windows Kits/10/Include")
                    let found = ((try? FileManager.default.contentsOfDirectory(atPath: include.path)) ?? []).sorted()
                        .filter { $0.hasPrefix("10.0.26100") }.last
                    return Self.present(found.map { include.appendingPathComponent($0).path })
                },
        ]
    }
}
