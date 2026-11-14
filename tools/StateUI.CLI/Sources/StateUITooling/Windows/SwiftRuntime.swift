// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol
#if os(Windows)
import WinSDK
#endif

/// The Swift runtime a WinUI head carries where nothing installs it - another architecture's build, a deployed
/// folder: the Swift installer keeps each architecture's as a merge module in its `Redistributables`, whose `File`
/// table names each file and whose cabinet holds them, read through Windows Installer's `msi.dll` and unpacked by
/// `expand.exe`. Unpacked once a module, into the application's cache, and copied from there.
/// Design: docs/design/tooling/winui-heads.md#the-swift-runtime
struct SwiftRuntime {
    /// The merge module of the toolchain `compiler` - `…\Toolchains\6.4.2+Asserts\usr\bin\swift.exe` - for
    /// `architecture`: `…\Redistributables\6.4.2\rtl.shared.<amd64|arm64>.msm`.
    static func module(compiler: URL, architecture: Architecture) -> URL {
        let toolchain = compiler.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let swift = toolchain.deletingLastPathComponent().deletingLastPathComponent()
        let version = toolchain.lastPathComponent.split(separator: "+").first.map(String.init) ?? toolchain.lastPathComponent
        return swift.appendingPathComponent("Redistributables").appendingPathComponent(version)
            .appendingPathComponent("rtl.shared.\(architecture == .x86_64 ? "amd64" : "arm64").msm")
    }

    /// What of the module a program runs with: every file but Foundation's `plutil.exe`.
    static func carried(_ name: String) -> Bool {
        name.lowercased() != "plutil.exe"
    }

    /// Lays `architecture`'s runtime in `directory`, unpacked into `cache` first where the module changed since.
    static func lay(in directory: URL, architecture: Architecture, compiler: URL, cache: URL, reporter: BuildReporter) async throws {
        let module = module(compiler: compiler, architecture: architecture)
        let files = FileManager.default
        guard files.fileExists(atPath: module.path) else {
            throw ToolingError(.missingToolchain, "No Swift runtime for \(architecture.rawValue): \(module.path) is missing.")
        }
        let modified = (try? files.attributesOfItem(atPath: module.path)[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let stamp = cache.appendingPathComponent("module.txt")
        let laid = "\(module.path) \(Int(modified))"
        if (try? String(contentsOf: stamp, encoding: .utf8)) != laid {
            reporter.progress("unpacking the Swift runtime for \(architecture.rawValue)")
            try? files.removeItem(at: cache)
            try await unpack(module, into: cache)
            try Data(laid.utf8).write(to: stamp)
        }
        for name in try files.contentsOfDirectory(atPath: cache.path).sorted() where name != "module.txt" {
            try? files.removeItem(at: directory.appendingPathComponent(name))
            try files.copyItem(at: cache.appendingPathComponent(name), to: directory.appendingPathComponent(name))
        }
    }

    /// The module's files, by their names, in `folder`.
    private static func unpack(_ module: URL, into folder: URL) async throws {
        #if os(Windows)
        let files = FileManager.default
        let work = folder.appendingPathComponent("cabinet")
        try files.createDirectory(at: work, withIntermediateDirectories: true)
        let installer = try MergeModule(module)
        let cabinet = work.appendingPathComponent("runtime.cab")
        try installer.writeCabinet(to: cabinet)
        try await ToolStep.run(.name("expand.exe"), [cabinet.path, "-F:*", work.path])
        for (key, name) in try installer.files() where carried(name) {
            let unpacked = work.appendingPathComponent(key)
            if files.fileExists(atPath: unpacked.path) {
                try files.moveItem(at: unpacked, to: folder.appendingPathComponent(name))
            }
        }
        try files.removeItem(at: work)
        #else
        throw ToolingError(.invalidConfiguration, "The Swift runtime of a WinUI head is unpacked on Windows.")
        #endif
    }
}

#if os(Windows)
/// A merge module read through Windows Installer: its `File` table and its cabinet stream.
private struct MergeModule {
    private typealias Open = @convention(c) (UnsafePointer<UInt16>?, UnsafePointer<UInt16>?, UnsafeMutablePointer<UInt32>?) -> UInt32
    private typealias OpenView = @convention(c) (UInt32, UnsafePointer<UInt16>?, UnsafeMutablePointer<UInt32>?) -> UInt32
    private typealias Execute = @convention(c) (UInt32, UInt32) -> UInt32
    private typealias Fetch = @convention(c) (UInt32, UnsafeMutablePointer<UInt32>?) -> UInt32
    private typealias GetString = @convention(c) (UInt32, UInt32, UnsafeMutablePointer<UInt16>?, UnsafeMutablePointer<UInt32>?) -> UInt32
    private typealias ReadStream = @convention(c) (UInt32, UInt32, UnsafeMutablePointer<CChar>?, UnsafeMutablePointer<UInt32>?) -> UInt32
    private typealias Close = @convention(c) (UInt32) -> UInt32

    private let module: URL
    private let library: HMODULE

    init(_ module: URL) throws {
        self.module = module
        guard let library = "msi.dll".withCString(encodedAs: UTF16.self, { LoadLibraryW($0) }) else {
            throw ToolingError(.missingToolchain, "Windows Installer's msi.dll does not load.")
        }
        self.library = library
    }

    private func function<F>(_ name: String, as type: F.Type) throws -> F {
        guard let symbol = GetProcAddress(library, name) else { throw ToolingError(.missingToolchain, "msi.dll offers no \(name).") }
        return unsafeBitCast(symbol, to: type)
    }

    /// The rows `query` selects, each a record handle the caller closes.
    private func rows(_ query: String, body: (UInt32) throws -> Void) throws {
        let open = try function("MsiOpenDatabaseW", as: Open.self)
        let openView = try function("MsiDatabaseOpenViewW", as: OpenView.self)
        let execute = try function("MsiViewExecute", as: Execute.self)
        let fetch = try function("MsiViewFetch", as: Fetch.self)
        let close = try function("MsiCloseHandle", as: Close.self)
        var database: UInt32 = 0
        // MSIDBOPEN_READONLY is the persist mode 0.
        guard module.path.withCString(encodedAs: UTF16.self, { open($0, nil, &database) }) == 0 else {
            throw ToolingError(.toolFailed, "Windows Installer does not open \(module.path).")
        }
        defer { _ = close(database) }
        var view: UInt32 = 0
        guard query.withCString(encodedAs: UTF16.self, { openView(database, $0, &view) }) == 0 else {
            throw ToolingError(.toolFailed, "Windows Installer does not read \(query) of \(module.path).")
        }
        defer { _ = close(view) }
        _ = execute(view, 0)
        var record: UInt32 = 0
        while fetch(view, &record) == 0 {
            defer { _ = close(record) }
            try body(record)
        }
    }

    /// Each file's key in the cabinet, to its long name.
    func files() throws -> [(key: String, name: String)] {
        let get = try function("MsiRecordGetStringW", as: GetString.self)
        func string(_ record: UInt32, _ field: UInt32) -> String {
            var buffer = [UInt16](repeating: 0, count: 1024)
            var size = UInt32(buffer.count)
            _ = get(record, field, &buffer, &size)
            return String(decoding: buffer.prefix(Int(size)), as: UTF16.self)
        }
        var found: [(String, String)] = []
        try rows("SELECT `File`, `FileName` FROM `File`") { record in
            let name = string(record, 2)
            found.append((string(record, 1), name.split(separator: "|").last.map(String.init) ?? name))
        }
        return found
    }

    /// The module's cabinet, written to `file`.
    func writeCabinet(to file: URL) throws {
        let read = try function("MsiRecordReadStream", as: ReadStream.self)
        var cabinet = Data()
        try rows("SELECT `Data` FROM `_Streams` WHERE `Name` = 'MergeModule.CABinet'") { record in
            var buffer = [CChar](repeating: 0, count: 1 << 20)
            while true {
                var size = UInt32(buffer.count)
                _ = read(record, 1, &buffer, &size)
                if size == 0 { break }
                buffer.withUnsafeBytes { cabinet.append(contentsOf: $0.prefix(Int(size))) }
            }
        }
        try cabinet.write(to: file)
    }
}
#endif
