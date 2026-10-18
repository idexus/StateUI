// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A name defines a key; the work is the key's number. These guards read every library source - the core, the
// foundation, the host layer, each Swift host and each backend - for a key made, or a key's name looked up, where the
// library works, and for every collection keyed by strings, each of which says here what its strings are.
// Design: docs/design/core/contracts.md#a-key-is-a-number

import Foundation
import XCTest

final class KeyGuardTests: XCTestCase {
    /// A name is made a key where the key is declared - a `static let`, a key type's own initializer, a member's - or
    /// once, as a host's realization is read at start-up. Anywhere else a key would be made during work: a hash of
    /// the name and a lock, each time.
    func testANameIsMadeAKeyOnlyWhereTheKeyIsDeclared() throws {
        try XCTAssertEqual(
            Self.offenders(Self.makesAKey, allowed: Self.makingKeys, skipping: Self.declaresOnce), [],
            "make the key once where it is declared - a `static let`, or the member holding it - and use it there")
    }

    /// The library's vocabulary is worked by its keys: a key's name is compared, or looked up, only where the words
    /// of a file or an export are read.
    func testNoKeyIsLookedUpByItsName() throws {
        try XCTAssertEqual(
            Self.offenders(Self.looksUpAName, allowed: Self.readingWords), [],
            "compare and look up the key itself - it is worked by its number - and leave its name to what is written")
    }

    /// A collection keyed by strings holds the words of a file, an export or a diagnostic, an identity of the
    /// application's data, or the native toolkit's own vocabulary - never the library's: each file holding one says
    /// which, here.
    func testEveryCollectionKeyedByStringsSaysWhatItsStringsAre() throws {
        try XCTAssertEqual(
            Self.offenders(Self.keyedByStrings, allowed: Self.keyedByWords), [],
            "key the library's vocabulary by its keys; a string key that is a file's word, an identity or the "
                + "toolkit's own vocabulary is listed here with which")
    }

    // MARK: - What is read

    private static let makesAKey =
        #"\b(KeyName|Prop|Event|Act|NodeType|VisualState|SceneKey|WindowType|PersistentKey|StyleKey)\((?!\))"#
    /// A `static` declaration, or one at a file's top - unindented.
    private static let declaresOnce = #"\bstatic (let|var)\b|^(public |@_spi\(Host\) public )?let "#
    private static let looksUpAName = #"\.name\s*(==|!=)|\w\??\[[^\[\]]*\.name\]"#
    private static let keyedByStrings = #"Set<String>|\[String: |Dictionary<String,"#

    /// Each file a match is allowed in, with why; the matches anywhere else, and a file listed that holds none.
    private static func offenders(
        _ pattern: String, allowed: [String: String], skipping skipped: String? = nil
    ) throws -> [String] {
        var offenders: [String] = []
        var matched: Set<String> = []

        for source in try librarySources() {
            for (index, line) in source.text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let code = line.trimmingCharacters(in: .whitespaces)
                guard !code.hasPrefix("//"), code.range(of: pattern, options: .regularExpression) != nil,
                      skipped.map({ line.range(of: $0, options: .regularExpression) == nil }) ?? true
                else { continue }

                matched.insert(source.file)
                if allowed[source.file] == nil { offenders.append("\(source.file):\(index + 1) \(code)") }
            }
        }

        let stale = allowed.keys.filter { !matched.contains($0) }.sorted().map { "\($0) is listed and holds none" }
        return offenders + stale
    }

    /// Every library source by its file name - unique in the library - and its text.
    private static func librarySources() throws -> [(file: String, text: String)] {
        let lib = SourceTree.repository.appendingPathComponent("lib/StateUI")
        var found: [String: String] = [:]

        for root in [SourceTree.sources, lib.appendingPathComponent("Foundation/Sources")] {
            for file in try SourceTree.files(under: root, entering: { _ in true }) where file.hasSuffix(".swift") {
                found[(file as NSString).lastPathComponent] = try String(
                    contentsOf: root.appendingPathComponent(file), encoding: .utf8)
            }
        }
        for source in try SourceTree.runtimeSources() {
            found[(source.path as NSString).lastPathComponent] = source.text
        }
        for source in try SourceTree.backendSources() where !source.path.contains("/Tests/") {
            let file = (source.path as NSString).lastPathComponent
            if file != "Package.swift" { found[file] = source.text }
        }

        return found.sorted { $0.key < $1.key }.map { (file: $0.key, text: $0.value) }
    }

    // MARK: - Where it is allowed, and why

    private static let keyType = "a key type: its initializer makes its key from the name declaring it"
    private static let member = "a contract's member: its keys are made once, as the member is declared"
    private static let startUp = "made once, as a host's realization or register is read at start-up"

    private static let makingKeys: [String: String] = [
        "Act.swift": keyType, "Event.swift": keyType, "NodeType.swift": keyType, "Prop.swift": keyType,
        "SceneKey.swift": keyType, "WindowType.swift": keyType, "StyleKey.swift": keyType,
        "Persistence.swift": keyType,
        "ElementAct.swift": member, "ElementEvent.swift": member, "ElementProperty.swift": member,
        "HostRealization.swift": startUp, "HostRealizations.swift": startUp, "HostDeclaration.swift": startUp,
        "CoreLink.swift": startUp,
        "StateWalk.swift": "a view type's key, made once a type, as the walk first meets it",
        "LibraryContracts.swift": "the members' facts: a table made once",
        "Differ+Arrangements.swift": "each arrangement's declared members: a table made once",
    ]

    private static let export = "the platform contract's export: records written by the names in its files"
    private static let store = "the store's words, by the name each is kept under: a key claims its own, once"

    private static let readingWords: [String: String] = [
        "HostDeclaration.swift": export, "HostRegister.swift": export,
        "KeptValuesText.swift": store, "KeptWord.swift": store, "Persistence.swift": store,
        "SceneRecord.swift": store,
    ]

    private static let identity = "identities of the application's data and of its elements, which come and go"
    private static let file = "the words of a file the platform keeps, by the names they are kept under"
    private static let register = "the host's register: the platform contract's words, read at start-up and in exports"
    private static let diagnostic = "the words of a diagnostic"
    private static let toolkit = "the native toolkit's own vocabulary"

    private static let keyedByWords: [String: String] = [
        // Identities.
        "Differ+Children.swift": identity, "Differ+Element.swift": identity + ": a state's path in its view",
        "StateStorage.swift": identity + ": a conversion's element and site", "ItemsSource.swift": identity,
        "LayoutEngine.swift": identity, "LayoutEngine+Change.swift": identity, "LayoutEngine+Item.swift": identity,
        "ItemsCells.swift": identity, "AppKitItemsView.swift": identity, "WebItemsView.swift": identity,
        "SceneRecord.swift": identity + ", and " + file,
        // Files.
        "HostBoundary.swift": file, "OpenScenes.swift": file, "Persistence.swift": file,
        "ValueText+Reading.swift": file, "KeptScenes.swift": file, "KeptValuesText.swift": file,
        "KeptWord.swift": file, "SceneValues.swift": file, "WindowRecord.swift": file,
        "AppKitWindowController+Lifecycle.swift": file, "HostRuntime.swift": file + ", and " + register,
        // The register and its exports.
        "HostDeclaration.swift": register, "HostRegister.swift": register, "HostVerdict.swift": register,
        "AppKitRealization.swift": register, "UIKitRealization.swift": register,
        "AndroidRealization.swift": register, "WinUIRealization.swift": register,
        "GTKRealization.swift": register, "WebRealization.swift": register,
        "CoreLink.swift": register + ", and " + diagnostic,
        // Diagnostics.
        "HostBoundary+Inspection.swift": diagnostic, "Complaint.swift": diagnostic, "Inspection.swift": diagnostic,
        "InspectorModel.swift": diagnostic, "HostRealizations.swift": diagnostic + ": the names nearest a miss",
        "StyleSheet.swift": "the names a style is based on, while the sheet is written",
        // The toolkits'.
        "LocaleTag.swift": "the locale data's scripts", "AppKitEnvironment.swift": toolkit + ": IOKit's dictionary",
        "AndroidPictures.swift": toolkit + ": the assets' files", "GTKStyleSheet.swift": toolkit + ": CSS rules",
        "GTKMenu.swift": toolkit + ": GAction names", "GTKQuestion.swift": toolkit + ": a dialog's responses",
        "WebDOMView.swift": toolkit + ": the DOM's styles and attributes", "WebFrameView.swift": toolkit,
        "WebImageView.swift": toolkit + ": the DOM's attributes",
    ]
}
