// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// An application's Android head, assembled from what SwiftPM built for one ABI: the native libraries and their
/// symbols, the application's pictures drawn three times over into the APK's assets, the host's drawables and the
/// launcher icon in its resources, and the APK Gradle makes of them with the host's Java - its package and the activity
/// the launcher opens read back from it.
/// Design: docs/design/tooling/android-heads.md
struct AndroidHead {
    /// The application's folder: `Resources` and `Platforms/Android`.
    var application: URL
    /// The application's name: `Gallery`.
    var name: String
    /// The library SwiftPM built: `GalleryAndroid`.
    var product: String
    /// The StateUI checkout: the host's Java and drawables.
    var library: URL
    var configuration: BuildConfiguration
    /// A folder kept from one build of this context to the next: libraries stripped, pictures drawn, Gradle's own.
    var work: URL
    var tools: AndroidTools

    /// What the head came to: the APK's path within the staging folder, its package and launcher activity.
    struct Package {
        var apk: String
        var package: String
        var activity: String
    }

    /// Assembles the head for `abi` from `binaries` - built with the Swift SDK `swiftSDK` and the NDK `ndk` - and lays
    /// the APK and the libraries' symbols in `staging`.
    ///
    /// - Throws: ``ToolingError`` - `MISSING_TOOLCHAIN` for no JDK 21 or aapt2, `TOOL_FAILED` where a step refused.
    func assemble(abi: String, binaries: URL, swiftSDK: String, ndk: URL, in staging: URL, reporter: BuildReporter) async throws -> Package {
        let files = FileManager.default
        guard let bundle = tools.swiftSDKBundle(swiftSDK) else {
            throw ToolingError(.missingToolchain, "\(swiftSDK) is listed but its bundle was not found.")
        }
        let arch = abi == "arm64-v8a" ? "aarch64" : abi == "armeabi-v7a" ? "armv7" : abi == "x86" ? "i686" : abi
        let runtime = bundle.appendingPathComponent("swift-android/swift-resources/usr/lib/swift-\(arch)/android")
        reporter.progress("gathering \(abi)'s libraries")
        let libraries = AndroidLibraries(ndk: ndk, abi: abi, binaries: binaries, runtime: runtime)
        let jniLibs = work.appendingPathComponent("jniLibs")
        let symbols = work.appendingPathComponent("symbols").appendingPathComponent(abi)
        _ = try await libraries.lay(product: product, into: jniLibs.appendingPathComponent(abi), symbols: symbols)
        try files.createDirectory(at: staging.appendingPathComponent("symbols"), withIntermediateDirectories: true)
        try files.copyItem(at: symbols, to: staging.appendingPathComponent("symbols").appendingPathComponent(abi))

        let assets = work.appendingPathComponent("assets")
        let res = work.appendingPathComponent("res")
        try drawPictures(into: assets.appendingPathComponent("images"), res: res, reporter: reporter)
        let drawables = res.appendingPathComponent("drawable")
        try? files.removeItem(at: drawables)
        try files.createDirectory(at: drawables, withIntermediateDirectories: true)
        let hostDrawables = library.appendingPathComponent("lib/StateUI/StateUI.Android/Resources/drawable")
        for drawable in ((try? files.contentsOfDirectory(atPath: hostDrawables.path)) ?? []).sorted() where drawable.hasSuffix(".xml") {
            try files.copyItem(at: hostDrawables.appendingPathComponent(drawable), to: drawables.appendingPathComponent(drawable))
        }

        guard let java = await tools.java21() else {
            throw ToolingError(.missingToolchain, "Gradle needs JDK 21: install it, or point JAVA_HOME at one.")
        }
        let gradle = try await tools.gradle(reporter: reporter)
        let task = "assemble" + configuration.rawValue.prefix(1).uppercased() + configuration.rawValue.dropFirst()
        let outputs = work.appendingPathComponent("gradle/outputs/apk").appendingPathComponent(configuration.rawValue)
        try? files.removeItem(at: outputs)
        reporter.progress("packaging \(name).apk")
        let said = Gathered()
        let outcome = try await ProcessRunner().run(ProcessRequest(
            .path(gradle.path), arguments: [
                "--project-dir", application.appendingPathComponent("Platforms/Android").path,
                "--project-cache-dir", work.appendingPathComponent("gradle-project").path,
                "--console=plain", "--quiet",
                "-Pstateui.build=\(work.appendingPathComponent("gradle").path)",
                "-Pstateui.java=\(library.appendingPathComponent("lib/StateUI/StateUI.Android/Java").path)",
                "-Pstateui.libraries=\(jniLibs.path)", "-Pstateui.assets=\(assets.path)", "-Pstateui.res=\(res.path)", task,
            ], environment: ProcessEnvironment.inherited.setting("JAVA_HOME", to: java.path).setting("ANDROID_HOME", to: tools.sdk.path)),
            output: { line in
                said.add(line)
                reporter.output(line)
            })
        try Task.checkCancellation()
        let made = ((try? files.contentsOfDirectory(atPath: outputs.path)) ?? []).sorted().first { $0.hasSuffix(".apk") }
        guard outcome.succeeded, let made else {
            let last = (said.lines(of: .standardError) + said.lines(of: .standardOutput)).suffix(12).joined(separator: "\n")
            throw ToolingError(.toolFailed, "Gradle made no APK of \(name); nothing was published:\n\(last)")
        }
        let apk = "\(name).apk"
        try files.copyItem(at: outputs.appendingPathComponent(made), to: staging.appendingPathComponent(apk))

        guard let aapt2 = tools.aapt2 else {
            throw ToolingError(.missingToolchain, "The Android SDK has no build tools' aapt2: install them with Android Studio's SDK Manager.")
        }
        let badging = await ToolOutput.standardOutput(.path(aapt2.path), ["dump", "badging", staging.appendingPathComponent(apk).path]) ?? ""
        guard let package = badging.firstMatch(of: /package: name='([^']+)'/).map({ String($0.1) }) else {
            throw ToolingError(.toolFailed, "aapt2 named no package in \(apk).")
        }
        let activity = badging.firstMatch(of: /launchable-activity: name='([^']+)'/).map { String($0.1) } ?? "stateui.android.StateUIActivity"
        return Package(apk: apk, package: package, activity: activity)
    }

    /// The application's pictures drawn into `images` and its launcher icon into `res`.
    private func drawPictures(into images: URL, res: URL, reporter: BuildReporter) throws {
        let files = FileManager.default
        let source = application.appendingPathComponent("Resources/Images")
        let artwork = application.appendingPathComponent("Resources/AppIcon")
        let (background, mark) = (artwork.appendingPathComponent("appicon_bkg.svg"), artwork.appendingPathComponent("appicon_mark.svg"))
        let icon = files.fileExists(atPath: background.path) && files.fileExists(atPath: mark.path)
        #if canImport(AppKit)
        if files.fileExists(atPath: source.path) {
            reporter.progress("drawing the pictures")
            try ApplePictures.draw(source, into: images)
        }
        if icon { try ApplePictures.drawAdaptiveIcon(background: background, mark: mark, into: res) }
        #else
        let drawn = ((try? files.contentsOfDirectory(atPath: source.path)) ?? []).contains { $0.lowercased().hasSuffix(".svg") }
        if drawn || icon {
            throw ToolingError(.invalidConfiguration, "\(name)'s SVG pictures and launcher icon are drawn for Android on a Mac for now.")
        }
        #endif
    }
}
