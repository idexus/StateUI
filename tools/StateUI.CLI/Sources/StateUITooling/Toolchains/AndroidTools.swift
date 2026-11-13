// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Where the Android host's tools stand: the SDK, the NDK, and the swift.org toolchain with the Swift SDK for
/// Android, found in the order the Android build takes them.
/// Design: docs/design/tooling/doctor.md#androids-tools
public struct AndroidTools: Sendable {
    private let environment: [String: String]
    private let home: URL

    /// The tools `environment` names, else the platform's own places under `home`.
    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.environment = environment
        self.home = home
    }

    /// The Android SDK: `ANDROID_HOME`, `ANDROID_SDK_ROOT`, else Android Studio's own place.
    public var sdk: URL {
        let named = [environment["ANDROID_HOME"], environment["ANDROID_SDK_ROOT"]].compactMap { $0 }.first { !$0.isEmpty }
        return named.map { URL(fileURLWithPath: $0) } ?? home.appendingPathComponent("Library/Android/sdk")
    }

    /// The swift.org toolchains of this Mac: Xcode's Swift cannot read the Swift SDK for Android.
    public var swiftOrgCompilers: [URL] {
        let files = FileManager.default
        let roots = [home.appendingPathComponent("Library/Developer/Toolchains"), URL(fileURLWithPath: "/Library/Developer/Toolchains")]
        let found = roots.flatMap { root in
            ((try? files.contentsOfDirectory(atPath: root.path)) ?? []).sorted().filter { $0.hasSuffix(".xctoolchain") }
                .map { root.appendingPathComponent($0).appendingPathComponent("usr/bin/swift") }
        }
        return (found + [home.appendingPathComponent(".swiftly/bin/swift")]).filter { files.fileExists(atPath: $0.path) }
    }

    /// The compiler the Android build takes and the Swift SDK for Android of its release: `SWIFT_BIN`, else `swift`
    /// on the search path, 6.4 or newer; where that is not swift.org's - Xcode's cannot read the SDK - the swift.org
    /// toolchain of the same release, as `build-swift.sh` looks for it.
    public func swift() async -> (compiler: URL, sdk: String)? {
        let named = environment["SWIFT_BIN"].flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0) }
        guard let builder = named ?? SearchPath(environment: environment).find("swift") else { return nil }
        let text = await ToolOutput.text(.path(builder.path), ["--version"]) ?? ""
        guard let release = Versions.swiftRelease(in: text), Versions.atLeast(release, "6.4") else { return nil }
        let list = await ToolOutput.text(.path(builder.path), ["sdk", "list"]) ?? ""
        guard let sdk = Versions.swiftSDK(of: release, in: list, family: "android") else { return nil }
        if Versions.isSwiftOrgBuild(text) { return (builder, sdk) }
        for compiler in swiftOrgCompilers {
            let own = await ToolOutput.text(.path(compiler.path), ["--version"]) ?? ""
            if Versions.isSwiftOrgBuild(own), Versions.swiftRelease(in: own) == release { return (compiler, sdk) }
        }
        return nil
    }

    /// The NDK the build takes: the one `ANDROID_NDK_ROOT` or `ANDROID_NDK_HOME` names, the one the Swift SDK
    /// `swiftSDK`'s setup linked into its bundle, else the Android SDK's newest.
    public func ndk(for swiftSDK: String?) -> URL? {
        let files = FileManager.default
        let isNDK = { (folder: URL) in files.fileExists(atPath: folder.appendingPathComponent("toolchains/llvm/prebuilt").path) }
        if let named = [environment["ANDROID_NDK_ROOT"], environment["ANDROID_NDK_HOME"]].compactMap({ $0 })
            .filter({ !$0.isEmpty }).map({ URL(fileURLWithPath: $0) }).first(where: isNDK) {
            return named
        }
        let roots = [home.appendingPathComponent("Library/org.swift.swiftpm/swift-sdks"), home.appendingPathComponent(".swiftpm/swift-sdks")]
        for root in roots {
            for bundle in ((try? files.contentsOfDirectory(atPath: root.path)) ?? []).sorted() where bundle.hasSuffix(".artifactbundle") {
                let folder = root.appendingPathComponent(bundle)
                guard let swiftSDK, let info = try? String(contentsOf: folder.appendingPathComponent("info.json"), encoding: .utf8),
                      info.contains("\"\(swiftSDK)\""),
                      let link = try? files.destinationOfSymbolicLink(atPath: folder.appendingPathComponent("swift-android/ndk-sysroot/usr/include").path),
                      let ndk = link.components(separatedBy: "/toolchains/llvm/prebuilt/").first
                else { continue }
                if isNDK(URL(fileURLWithPath: ndk)) { return URL(fileURLWithPath: ndk) }
            }
        }
        let folder = sdk.appendingPathComponent("ndk")
        let newest = ((try? files.contentsOfDirectory(atPath: folder.path)) ?? []).sorted { Versions.compare($0, $1) < 0 }.last
        return newest.map { folder.appendingPathComponent($0) }.flatMap { isNDK($0) ? $0 : nil }
    }
}
