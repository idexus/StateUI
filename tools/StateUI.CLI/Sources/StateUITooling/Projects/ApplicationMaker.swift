// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// A new application: a checkout's HelloWorld under another name, naming that checkout by the path from it.
/// Design: docs/design/tooling/projects.md#a-new-application
public struct ApplicationMaker: Sendable {
    /// A maker.
    public init() {}

    /// Why `name` cannot name an application, or `nil`: letters and digits starting with a letter, as a Swift
    /// module, a process, a package identifier and a folder all take it - and not the library's own name.
    public static func problem(with name: String) -> String? {
        guard name.wholeMatch(of: /[A-Za-z][A-Za-z0-9]*/) != nil else {
            return "'\(name)' cannot name an application: letters and digits only, starting with a letter."
        }
        return name == "StateUI" ? "'StateUI' is the library. Pick a name of the application's own." : nil
    }

    /// Makes application `name` in `parent` from `checkout`'s HelloWorld, its `stateui.json` naming it `identifier` -
    /// `com.example.<name>` where none is given - at version 1.0.0, build 1, with the heads of `platforms` alone where
    /// they are given: written beside, then put in place whole.
    ///
    /// - Returns: The new application's folder.
    /// - Throws: ``ToolingError`` - a name or identifier that cannot be, no platform, a folder already holding
    ///   something, no checkout.
    public func make(
        _ name: String, identifier: String? = nil, platforms: [HostFamily]? = nil, in parent: URL, from checkout: URL
    ) throws(ToolingError) -> URL {
        if platforms?.isEmpty == true { throw ToolingError(.invalidName, "\(name) cannot be made for no platform.") }
        if let problem = Self.problem(with: name) { throw ToolingError(.invalidName, problem) }
        let file = ApplicationFile(identifier: identifier ?? "com.example.\(name.lowercased())", version: "1.0.0", build: 1)
        if let problem = file.problem { throw ToolingError(.invalidName, "\(name) cannot be made: \(problem)") }
        guard let checkout = Checkout(at: RealPath.lexical(checkout)) else {
            throw ToolingError(.projectNotFound, "No StateUI checkout stands at \(checkout.path).")
        }
        let files = FileManager.default
        try? files.createDirectory(at: parent, withIntermediateDirectories: true)
        let destination = RealPath.of(parent).appendingPathComponent(name)
        if let taken = Folders.taken(destination) { throw ToolingError(.alreadyExists, taken) }
        let staging = destination.deletingLastPathComponent()
            .appendingPathComponent(".\(name).stateui-new-\(UUID().uuidString.lowercased())")
        do {
            try copy(checkout.root.appendingPathComponent("apps/HelloWorld"), to: staging, naming: name)
            try nameCheckout(checkout.root, in: staging, standingAt: destination)
            try file.write(to: staging.appendingPathComponent(ApplicationFile.name))
            for host in HostFamily.allCases where platforms.map({ !$0.contains(host) }) ?? false {
                try? files.removeItem(at: staging.appendingPathComponent("Platforms").appendingPathComponent(host.folder))
            }
            if files.fileExists(atPath: destination.path) { try files.removeItem(at: destination) }
            try files.moveItem(at: staging, to: destination)
        } catch {
            try? files.removeItem(at: staging)
            throw ToolingError(.toolFailed, "\(name) could not be made in \(parent.path): \(error.localizedDescription)")
        }
        return destination
    }

    /// Copies `model` to `copy`, every hidden entry left out, `HelloWorld` renamed to `name` in names and in every
    /// text, `helloworld` to `name` in lower case.
    private func copy(_ model: URL, to copy: URL, naming name: String) throws {
        let files = FileManager.default
        try files.createDirectory(at: copy, withIntermediateDirectories: true)
        for entry in try files.contentsOfDirectory(atPath: model.path).sorted() where !entry.hasPrefix(".") {
            let source = model.appendingPathComponent(entry)
            let target = copy.appendingPathComponent(entry.replacingOccurrences(of: "HelloWorld", with: name))
            var isFolder: ObjCBool = false
            if files.fileExists(atPath: source.path, isDirectory: &isFolder), isFolder.boolValue {
                try self.copy(source, to: target, naming: name)
            } else {
                let contents = try Data(contentsOf: source)
                let renamed = String(data: contents, encoding: .utf8).map {
                    Data($0.replacingOccurrences(of: "HelloWorld", with: name)
                        .replacingOccurrences(of: "helloworld", with: name.lowercased()).utf8)
                }
                try (renamed ?? contents).write(to: target)
            }
        }
    }

    /// Names `checkout` in the manifest of the application in `folder`, which will stand at `destination`: every
    /// `../..` - the checkout's root as HelloWorld says it - the path from there instead.
    private func nameCheckout(_ checkout: URL, in folder: URL, standingAt destination: URL) throws {
        let path = Self.relativePath(from: destination, to: checkout)
        guard path != "../.." else { return }
        let manifest = folder.appendingPathComponent("Package.swift")
        let text = try String(contentsOf: manifest, encoding: .utf8)
        try Data(text.replacingOccurrences(of: "../..", with: path).utf8).write(to: manifest)
    }

    /// The path from folder `from` to `to`, written with `/` as SwiftPM reads it everywhere.
    static func relativePath(from: URL, to: URL) -> String {
        let source = RealPath.of(from.deletingLastPathComponent()).appendingPathComponent(from.lastPathComponent)
            .pathComponents
        let target = RealPath.of(to).pathComponents
        #if os(Windows)
        // A folder on another drive has no path from here but its own.
        let drive = { (parts: [String]) in parts.first { $0 != "/" }?.lowercased() }
        if drive(source) != drive(target) { return target.filter { $0 != "/" }.joined(separator: "/") }
        #endif
        var shared = 0
        while shared < min(source.count, target.count), source[shared] == target[shared] { shared += 1 }
        guard shared > 0 else { return target.joined(separator: "/") }
        let up = Array(repeating: "..", count: source.count - shared)
        let down = Array(target[shared...])
        return (up + down).isEmpty ? "." : (up + down).joined(separator: "/")
    }

    /// The folder `path` names from `folder` - what ``relativePath(from:to:)`` wrote, read back: a whole path, another
    /// drive's on Windows, names it by itself.
    static func folder(named path: String, from folder: URL) -> URL {
        let whole = path.hasPrefix("/") || (Machine.current.system == "windows" && path.dropFirst().hasPrefix(":"))
        return RealPath.lexical(whole ? URL(fileURLWithPath: path) : folder.appendingPathComponent(path))
    }
}
