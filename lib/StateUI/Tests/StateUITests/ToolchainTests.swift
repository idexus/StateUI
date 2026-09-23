// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

/// StateUI builds with ONE Swift release on every platform - Xcode's on
/// macOS, swift.org's everywhere else - and with one Xcode and one NDK.
///
/// The release is written in many places that nothing else compares: every
/// manifest's tools version, the continuous integration's toolchains, images
/// and SDKs, the scripts, the handbook and the template. A release named in
/// one of them and not the others is a platform building with a compiler the
/// rest never saw. These read every one of them.
final class ToolchainTests: XCTestCase {
    /// Every text file the build, the continuous integration and the handbook
    /// are written in, as `(path, text)`, read once.
    private static let texts: [(path: String, text: String)] = {
        let repository = Fixtures.repository
        let kinds: Set<String> = ["swift", "md", "yml", "yaml", "sh", "ps1", "json", "csproj", "targets", "props", "ts"]

        // What a build writes, the wire fixtures, and the pages rendered from
        // the contracts - none of them names a toolchain.
        let skipped: Set<String> = [
            ".build", ".build-appkit", ".build-maui", ".git", "bin", "obj", "node_modules", "out",
            "lib/StateUI/Tests/Fixtures", "docs/controls",
        ]

        let entered = { (relative: String) -> Bool in
            let name = String(relative.split(separator: "/").last ?? "")
            return !skipped.contains(name) && !skipped.contains(relative)
        }

        let paths = (try? Fixtures.files(under: repository, entering: entered)) ?? []

        return paths.compactMap { relative in
            guard kinds.contains(URL(fileURLWithPath: relative).pathExtension) else { return nil }
            guard let text = try? String(contentsOf: repository.appendingPathComponent(relative), encoding: .utf8) else {
                return nil
            }
            return (relative, text)
        }
    }()

    /// Every match of `pattern`'s first group, as `(where, value)`.
    private func values(of pattern: String) throws -> [(place: String, value: String)] {
        let expression = try NSRegularExpression(pattern: pattern)
        var found: [(String, String)] = []

        for (path, text) in Self.texts {
            let whole = NSRange(text.startIndex..., in: text)

            for match in expression.matches(in: text, range: whole) {
                guard let range = Range(match.range(at: 1), in: text) else { continue }

                let line = text[..<range.lowerBound].reduce(1) { $1 == "\n" ? $0 + 1 : $0 }
                found.append(("\(path):\(line)", String(text[range])))
            }
        }

        return found
    }

    /// One release, two spellings: swift.org names its files `6.4.0` while
    /// the compiler calls itself `6.4`.
    private func release(_ version: String) -> String {
        let parts = version.split(separator: ".")
        return parts.count == 3 && parts[2] == "0" ? parts[0...1].joined(separator: ".") : version
    }

    /// The release every manifest asks for, which is the one everything else
    /// has to name.
    private func manifestRelease() throws -> String {
        let manifests = try values(of: #"(?m)^// swift-tools-version:(\d+\.\d+(?:\.\d+)?)"#)
            .filter { $0.place.hasSuffix("Package.swift:1") }

        XCTAssertGreaterThan(manifests.count, 4, "the walk found almost none of the manifests")
        XCTAssertEqual(
            Set(manifests.map(\.value)).count, 1,
            "every manifest asks for one tools version: \(manifests.map { "\($0.place) \($0.value)" })")

        return release(try XCTUnwrap(manifests.first?.value))
    }

    /// The toolchains, images, SDKs and prose all name the manifests' release,
    /// and every one of them that names a patch release names the same one.
    func testEveryPlaceThatNamesSwiftNamesOneRelease() throws {
        let expected = try manifestRelease()

        let named = try [
            #"swift-(\d+\.\d+(?:\.\d+)?)-(?:RELEASE|release)"#,
            #"swift:(\d+\.\d+(?:\.\d+)?)-"#,
            #"swift-build: (\d+\.\d+(?:\.\d+)?)-RELEASE"#,
            #"swiftlang-(\d+\.\d+)\.\d+"#,
            #"\bSwift (\d+\.\d+(?:\.\d+)?)\b"#,
        ].flatMap(values(of:))

        XCTAssertGreaterThan(named.count, 20, "the walk found almost none of the places that name Swift")

        let other = named.filter { release($0.value) != expected }
        XCTAssertEqual(other.map { "\($0.place) \($0.value)" }, [], "Swift \(expected) is the one release")

        let patches = Set(named.map(\.value).filter { $0.split(separator: ".").count == 3 })
        XCTAssertLessThanOrEqual(patches.count, 1, "one patch release everywhere, not \(patches.sorted())")
    }

    /// The continuous integration, the handbook and the iOS and Mac Catalyst
    /// frameworks name one Xcode: `net10.0-ios27.0` builds against .NET's
    /// packs for Xcode 27.
    func testEveryPlaceThatNamesXcodeNamesOne() throws {
        let named = try [
            #"Xcode_(\d+)(?:\.\d+)*\.app"#, #"\bXcode (\d+)(?:\.\d+)?\b"#,
            #"net\d+\.\d+-(?:ios|maccatalyst)(\d+)\.\d+"#,
        ].flatMap(values(of:))

        XCTAssertGreaterThan(named.count, 10, "the walk found almost none of the places that name Xcode")
        XCTAssertEqual(
            Set(named.map(\.value)).count, 1,
            "one Xcode: \(named.map { "\($0.place) \($0.value)" })")

        // A framework with no version takes whichever packs .NET defaults to,
        // and those follow another Xcode.
        let unversioned = try values(of: #"(net\d+\.\d+-(?:ios|maccatalyst))(?![\d.])"#)
        XCTAssertEqual(
            unversioned.map { "\($0.place) \($0.value)" }, [],
            "an iOS or Mac Catalyst framework names the Xcode it builds against")
    }

    /// The continuous integration and the handbook name one NDK, the one the
    /// Swift SDK for Android is built with.
    func testEveryPlaceThatNamesTheNDKNamesOne() throws {
        let named = try [
            #"\bNDK (\d+)\b"#, #"ndk;(\d+)\."#, #"ANDROID_NDK_VERSION: (\d+)\."#, #"android-ndk-r(\d+)"#,
        ].flatMap(values(of:))

        XCTAssertGreaterThan(named.count, 3, "the walk found almost none of the places that name the NDK")
        XCTAssertEqual(
            Set(named.map(\.value)).count, 1,
            "one NDK: \(named.map { "\($0.place) \($0.value)" })")
    }
}
