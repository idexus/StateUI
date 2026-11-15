// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// The C++/WinRT projection the WinUI host's relay includes - of the Windows SDK, WinUI, the Windows App SDK and
/// WebView2 - in `lib/StateUI/StateUI.WinUI/.projection`, with WinUI's header for drawing with DirectX into its
/// elements beside it; made again when a pin changes, as its `versions.txt` says.
/// Design: docs/design/tooling/winui-heads.md#the-projection
struct WinUIProjection {
    /// The StateUI checkout.
    var library: URL
    var packages: WinUIPackages

    static let interop = "microsoft.ui.xaml.media.dxinterop.h"

    var folder: URL { library.appendingPathComponent("lib/StateUI/StateUI.WinUI/.projection") }

    /// Whether the projection stands for the pins.
    var isCurrent: Bool {
        let stamp = (try? String(contentsOf: folder.appendingPathComponent("versions.txt"), encoding: .utf8)) ?? ""
        return stamp.trimmingCharacters(in: .whitespacesAndNewlines) == WinUIPackages.stamp
            && FileManager.default.fileExists(atPath: folder.appendingPathComponent(Self.interop).path)
    }

    /// Makes the projection where it does not stand for the pins.
    func ready(reporter: BuildReporter) async throws {
        if isCurrent { return }
        let cppwinrt = try await packages.folder("microsoft.windows.cppwinrt", reporter: reporter).appendingPathComponent("bin/cppwinrt.exe")
        let winUI = try await packages.folder("microsoft.windowsappsdk.winui", reporter: reporter)
        let foundation = try await packages.folder("microsoft.windowsappsdk.foundation", reporter: reporter)
        let experiences = try await packages.folder("microsoft.windowsappsdk.interactiveexperiences", reporter: reporter)
        let webView = try await packages.folder("microsoft.web.webview2", reporter: reporter)
        reporter.progress("generating the C++/WinRT projection")
        try? FileManager.default.removeItem(at: folder)
        try await ToolStep.run(.path(cppwinrt.path), [
            "-input", "sdk", "-input", winUI.appendingPathComponent("metadata").path,
            "-input", foundation.appendingPathComponent("metadata").path,
            "-input", experiences.appendingPathComponent("metadata/10.0.18362.0").path,
            "-input", webView.appendingPathComponent("lib/Microsoft.Web.WebView2.Core.winmd").path, "-output", folder.path,
        ], limit: .seconds(900))
        try FileManager.default.copyItem(
            at: winUI.appendingPathComponent("include").appendingPathComponent(Self.interop), to: folder.appendingPathComponent(Self.interop))
        try Data((WinUIPackages.stamp + "\n").utf8).write(to: folder.appendingPathComponent("versions.txt"))
    }
}
