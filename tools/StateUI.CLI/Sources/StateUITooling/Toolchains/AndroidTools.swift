// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// Where the Android host's tools stand: the SDK with adb, the emulator and aapt2, the NDK, JDK 21, Gradle, and the
/// swift.org toolchain with the Swift SDK for Android, found in the order the Android build takes them.
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
        #if os(macOS)
        let studio = "Library/Android/sdk"
        #else
        let studio = "Android/Sdk"
        #endif
        return named.map { URL(fileURLWithPath: $0) } ?? home.appendingPathComponent(studio)
    }

    /// What a program's file name ends with on this system: `.exe` on Windows.
    public static var programSuffix: String {
        #if os(Windows)
        ".exe"
        #else
        ""
        #endif
    }

    /// The SDK's `adb`.
    public var adb: URL { sdk.appendingPathComponent("platform-tools/adb\(Self.programSuffix)") }

    /// The SDK's emulator.
    public var emulator: URL { sdk.appendingPathComponent("emulator/emulator\(Self.programSuffix)") }

    /// The newest build tools' `aapt2`, or `nil` where the SDK has none.
    public var aapt2: URL? {
        let tools = sdk.appendingPathComponent("build-tools")
        let versions = ((try? FileManager.default.contentsOfDirectory(atPath: tools.path)) ?? []).sorted { Versions.compare($0, $1) < 0 }
        return versions.reversed().map { tools.appendingPathComponent($0).appendingPathComponent("aapt2\(Self.programSuffix)") }
            .first(where: Self.runnable)
    }

    /// Whether `program` can be run: executable, or on Windows, which keeps no such mark, there.
    static func runnable(_ program: URL) -> Bool {
        #if os(Windows)
        FileManager.default.fileExists(atPath: program.path)
        #else
        FileManager.default.isExecutableFile(atPath: program.path)
        #endif
    }

    /// The Gradle every head builds with.
    public static let gradleVersion = "9.4.1"

    /// Gradle's launcher in its `bin`: `gradle.bat` on Windows.
    public static var gradleLauncher: String {
        #if os(Windows)
        "gradle.bat"
        #else
        "gradle"
        #endif
    }

    /// JDK 21, which Gradle and the Android plugin run on: `java_home -v 21` on a Mac, else `JAVA_HOME` where it is
    /// 21, else a JDK 21 of the system's own JVM folder.
    public func java21() async -> URL? {
        #if os(macOS)
        if let found = await ToolOutput.standardOutput(.path("/usr/libexec/java_home"), ["-v", "21"])?
            .trimmingCharacters(in: .whitespacesAndNewlines), !found.isEmpty {
            return URL(fileURLWithPath: found)
        }
        #endif
        var candidates = environment["JAVA_HOME"].map { [URL(fileURLWithPath: $0)] } ?? []
        let system = URL(fileURLWithPath: "/usr/lib/jvm")
        candidates += ((try? FileManager.default.contentsOfDirectory(atPath: system.path)) ?? []).sorted()
            .filter { $0.contains("21") }.map { system.appendingPathComponent($0) }
        for home in candidates {
            let said = await ToolOutput.text(.path(home.appendingPathComponent("bin/java").path), ["-version"]) ?? ""
            if said.contains("\"21.") { return home }
        }
        return nil
    }

    /// Gradle ``gradleVersion`` from the wrapper's cache - where a project's wrapper or an earlier build put it - or
    /// `nil` where it is not there yet.
    public var cachedGradle: URL? {
        let dists = home.appendingPathComponent(".gradle/wrapper/dists/gradle-\(Self.gradleVersion)-bin")
        let files = FileManager.default
        return ((try? files.contentsOfDirectory(atPath: dists.path)) ?? []).sorted()
            .map { dists.appendingPathComponent($0).appendingPathComponent("gradle-\(Self.gradleVersion)/bin/\(Self.gradleLauncher)") }
            .first(where: Self.runnable)
    }

    /// Gradle ``gradleVersion``: the cached one, else downloaded from Gradle's own distributions into the wrapper's
    /// cache, as its wrapper would.
    ///
    /// - Throws: ``ToolingError`` `TOOL_FAILED` where the download or its unpacking failed.
    public func gradle(reporter: BuildReporter = BuildReporter()) async throws -> URL {
        if let cachedGradle { return cachedGradle }
        let folder = home.appendingPathComponent(".gradle/wrapper/dists/gradle-\(Self.gradleVersion)-bin/stateui")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let archive = folder.appendingPathComponent("gradle.zip")
        reporter.progress("downloading Gradle \(Self.gradleVersion)")
        try await ToolStep.run("curl", ["-fsSL", "https://services.gradle.org/distributions/gradle-\(Self.gradleVersion)-bin.zip", "-o", archive.path], limit: .seconds(600))
        try await ToolStep.run("unzip", ["-q", "-o", archive.path, "-d", folder.path], limit: .seconds(300))
        try? FileManager.default.removeItem(at: archive)
        guard let cachedGradle else { throw ToolingError(.toolFailed, "Gradle \(Self.gradleVersion) unpacked into no bin/gradle.") }
        return cachedGradle
    }

    /// The major release of the NDK at `ndk`, from its `source.properties`: `30`.
    public static func ndkMajor(of ndk: URL) -> Int? {
        guard let text = try? String(contentsOf: ndk.appendingPathComponent("source.properties"), encoding: .utf8),
              let match = text.firstMatch(of: /Pkg\.Revision\s*=\s*(\d+)/)
        else { return nil }
        return Int(match.1)
    }

    /// The bundle of the Swift SDK `swiftSDK`: the `.artifactbundle` whose `info.json` names it.
    public func swiftSDKBundle(_ swiftSDK: String) -> URL? {
        let files = FileManager.default
        let roots = [home.appendingPathComponent("Library/org.swift.swiftpm/swift-sdks"), home.appendingPathComponent(".swiftpm/swift-sdks")]
        for root in roots {
            for bundle in ((try? files.contentsOfDirectory(atPath: root.path)) ?? []).sorted() where bundle.hasSuffix(".artifactbundle") {
                let folder = root.appendingPathComponent(bundle)
                if let info = try? String(contentsOf: folder.appendingPathComponent("info.json"), encoding: .utf8),
                   info.contains("\"\(swiftSDK)\"") {
                    return folder
                }
            }
        }
        return nil
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
        if let folder = swiftSDK.flatMap(swiftSDKBundle),
           let link = try? files.destinationOfSymbolicLink(atPath: folder.appendingPathComponent("swift-android/ndk-sysroot/usr/include").path),
           let ndk = link.components(separatedBy: "/toolchains/llvm/prebuilt/").first, isNDK(URL(fileURLWithPath: ndk)) {
            return URL(fileURLWithPath: ndk)
        }
        let folder = sdk.appendingPathComponent("ndk")
        let newest = ((try? files.contentsOfDirectory(atPath: folder.path)) ?? []).sorted { Versions.compare($0, $1) < 0 }.last
        return newest.map { folder.appendingPathComponent($0) }.flatMap { isNDK($0) ? $0 : nil }
    }
}
