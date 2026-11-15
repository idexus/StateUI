// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// The native libraries an Android head ships for one ABI: its product and everything it needs, by `DT_NEEDED`,
/// from SwiftPM's build, the Swift SDK's runtime and the NDK's C++ library - a library the NDK's sysroot declares for
/// the API being the platform's own - each laid stripped in `jniLibs/<abi>` and whole in `symbols/<abi>`.
/// Design: docs/design/tooling/android-heads.md#the-native-libraries
struct AndroidLibraries {
    /// The NDK the build used.
    var ndk: URL
    /// The ABI: `arm64-v8a`.
    var abi: String
    /// The folder SwiftPM laid the product in.
    var binaries: URL
    /// The Swift SDK's runtime for the ABI.
    var runtime: URL
    /// The oldest API the head runs on.
    var api = 28

    /// The NDK's name of the ABI's target: `aarch64-linux-android`.
    var ndkTarget: String {
        ["arm64-v8a": "aarch64-linux-android", "x86_64": "x86_64-linux-android", "armeabi-v7a": "arm-linux-androideabi",
         "x86": "i686-linux-android"][abi] ?? abi
    }

    /// The NDK's prebuilt toolchain for this machine.
    var prebuilt: URL? {
        let folder = ndk.appendingPathComponent("toolchains/llvm/prebuilt")
        return ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).sorted().first.map(folder.appendingPathComponent)
    }

    /// The libraries `root` needs, itself first, closed over what `needed` says each needs - the platform's own left out.
    static func closure(of root: String, needed: (String) async throws -> [String], isPlatform: (String) -> Bool) async rethrows -> [String] {
        var queue = [root]
        var packaged: [String] = []
        while !queue.isEmpty {
            let library = queue.removeFirst()
            guard !packaged.contains(library), !isPlatform(library) else { continue }
            packaged.append(library)
            queue += try await needed(library).filter { $0 != library }
        }
        return packaged
    }

    /// Lays `lib<product>.so` and its closure in `libraries` stripped and in `symbols` whole - again only where its
    /// source changed - and removes what the closure no longer holds; answers the libraries laid.
    ///
    /// - Throws: ``ToolingError`` `TOOL_FAILED` where a library is needed and found nowhere, or the NDK's tools refuse.
    func lay(product: String, into libraries: URL, symbols: URL) async throws -> [String] {
        guard let prebuilt else { throw ToolingError(.toolFailed, "\(ndk.path) holds no prebuilt toolchain.") }
        let bin = prebuilt.appendingPathComponent("bin")
        let sysroot = prebuilt.appendingPathComponent("sysroot/usr/lib").appendingPathComponent(ndkTarget)
        let platform = sysroot.appendingPathComponent("\(api)")
        let files = FileManager.default
        let source = { (library: String) -> URL? in
            let found = [binaries, runtime].map { $0.appendingPathComponent(library) }.first { files.fileExists(atPath: $0.path) }
            return found ?? (library == "libc++_shared.so" ? sysroot.appendingPathComponent(library) : nil)
        }
        let readelf = ProcessExecutable.path(bin.appendingPathComponent("llvm-readelf").path)
        let laid = try await Self.closure(of: "lib\(product).so", needed: { library in
            guard let file = source(library) else {
                throw ToolingError(.toolFailed, "\(library) is needed for \(abi) and found nowhere: not in the build, the Swift SDK's runtime or the NDK.")
            }
            let said = await ToolOutput.standardOutput(readelf, ["--needed-libs", file.path]) ?? ""
            return said.matches(of: /lib[A-Za-z0-9_.+-]+\.so/).map { String($0.output) }
        }, isPlatform: { files.fileExists(atPath: platform.appendingPathComponent($0).path) })

        try files.createDirectory(at: libraries, withIntermediateDirectories: true)
        try files.createDirectory(at: symbols, withIntermediateDirectories: true)
        let strip = ProcessExecutable.path(bin.appendingPathComponent("llvm-strip").path)
        for library in laid {
            guard let from = source(library) else { continue }
            let whole = symbols.appendingPathComponent(library)
            let changed = { (url: URL) in (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) }
            if changed(whole) == nil || changed(whole) != changed(from) {
                try? files.removeItem(at: whole)
                try files.copyItem(at: from, to: whole)
                let stripped = libraries.appendingPathComponent(library)
                try? files.removeItem(at: stripped)
                try await ToolStep.run(strip, ["--strip-unneeded", "-o", stripped.path, from.path])
                if let date = changed(from) {
                    try files.setAttributes([.modificationDate: date], ofItemAtPath: whole.path)
                }
            }
        }
        for folder in [libraries, symbols] {
            for name in (try? files.contentsOfDirectory(atPath: folder.path)) ?? [] where name.hasSuffix(".so") && !laid.contains(name) {
                try files.removeItem(at: folder.appendingPathComponent(name))
            }
        }
        return laid
    }
}
