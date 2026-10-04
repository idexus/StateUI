// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

final class NativeProjectTests: XCTestCase {
    /// Every application is one Swift package shared by one head per host: the
    /// AppKit executable in `Platforms/AppKit` and the Android head in
    /// `Platforms/Android`, both compiling the same `Sources/`.
    func testEveryApplicationSharesItsSourcesBetweenItsHostHeads() throws {
        for name in ["Gallery", "HelloWorld"] {
            let app = SourceTree.repository.appendingPathComponent("apps/\(name)")
            for relative in [
                "Package.swift", "Sources", "Resources", "Platforms/AppKit/main.swift",
                "Platforms/Android/build.gradle.kts", "Platforms/Android/Swift/\(name)Android.swift",
            ] {
                XCTAssertTrue(
                    FileManager.default.fileExists(
                        atPath: app.appendingPathComponent(relative).path),
                    "\(name) is missing \(relative)")
            }

            let manifest = try String(
                contentsOf: app.appendingPathComponent("Package.swift"),
                encoding: .utf8)
            XCTAssertTrue(manifest.contains("name: \"\(name)UI\""))
            XCTAssertTrue(declaresHead(manifest, of: name, for: "AppKit", in: "Platforms/AppKit"))

            let entry = try String(
                contentsOf: app.appendingPathComponent("Platforms/AppKit/main.swift"),
                encoding: .utf8)
            XCTAssertTrue(entry.contains("import StateUIAppKit"))
            XCTAssertTrue(entry.contains("StateUIAppKit.run("))

            let registration = try String(
                contentsOf: app.appendingPathComponent("Sources/\(name)App.swift"),
                encoding: .utf8)
            XCTAssertTrue(
                registration.contains("@_cdecl(\"stateui_app_register\")"),
                "\(name)'s module does not register the application for its Android head")
        }
    }

    /// Every head gets its host from `lib/StateUI.Head`, which reads the build's
    /// `STATEUI_HOST` variable once for every application: it depends on that host's
    /// package alone and re-exports it, and a WinUI head links as a windowed
    /// application. No application names a host's package itself, and each
    /// reads the same hosts the head package does.
    func testEveryHeadGetsItsHostFromTheHeadPackage() throws {
        let repository = SourceTree.repository
        func text(_ relative: String) throws -> String {
            try String(contentsOf: repository.appendingPathComponent(relative), encoding: .utf8)
        }
        let hosts = ["AppKit", "UIKit", "Android", "WinUI", "GTK"]
        let list = "let host = [" + hosts.map { "\"\($0)\"" }.joined(separator: ", ") + "]"

        let manifest = try text("lib/StateUI.Head/Package.swift")
        for shape in [list, "path: \"../StateUI/StateUI.\\($0)\"", "\"/SUBSYSTEM:WINDOWS\"", "\"/ENTRY:mainCRTStartup\""] {
            XCTAssertTrue(manifest.contains(shape), "lib/StateUI.Head/Package.swift does not say \(shape)")
        }
        let source = try text("lib/StateUI.Head/Sources/StateUIHead.swift")
        for host in hosts {
            XCTAssertTrue(
                FileManager.default.fileExists(
                    atPath: repository.appendingPathComponent("lib/StateUI/StateUI.\(host)/Package.swift").path),
                "no host package lib/StateUI/StateUI.\(host)")
            XCTAssertTrue(
                source.contains("if \(host.uppercased())\n@_exported import StateUI\(host)\n"),
                "StateUIHead does not re-export StateUI\(host) under #if \(host.uppercased())")
        }

        for application in try SourceTree.applications() {
            let name = application.lastPathComponent
            let manifest = try String(contentsOf: application.appendingPathComponent("Package.swift"), encoding: .utf8)
            XCTAssertTrue(manifest.contains(list), "\(name) reads other hosts than lib/StateUI.Head")
            XCTAssertTrue(
                manifest.contains(".package(name: \"StateUIHead\", path: \"../../lib/StateUI.Head\")"),
                "\(name) does not depend on lib/StateUI.Head")
            for host in hosts {
                XCTAssertFalse(
                    manifest.contains("lib/StateUI.\(host)\""), "\(name) names StateUI\(host)'s package itself")
            }
        }
    }

    /// Whether an application's manifest declares its head for `host`, named
    /// `<Name><Host>`, in `path`, with StateUIHead bringing the host: by name,
    /// or through the case every head without a module of its own shares.
    private func declaresHead(_ manifest: String, of name: String, for host: String, in path: String) -> Bool {
        let named = manifest.contains("name: \"\(name)\(host)\"") && manifest.contains("path: \"\(path)\"")
        let shared = path == "Platforms/\(host)"
            && manifest.contains("name: \"\(name)\\(host)\"") && manifest.contains("path: \"Platforms/\\(host)\"")
        return manifest.contains(".product(name: \"StateUIHead\", package: \"StateUIHead\")") && (named || shared)
    }

    /// Every host is Swift, and code in a platform's own language is a relay
    /// beneath one - Java through JNI, C++ behind a C ABI. No C# source, .NET
    /// project or solution stands in the tree: there is no host for it.
    func testNoDotNetProjectStandsInTheTree() throws {
        // Build output never: Gradle's `build/`, the extension's packages and
        // its compiled code besides what `entersSources` leaves out.
        let entered = { (relative: String) -> Bool in
            SourceTree.entersSources(relative)
                && !["node_modules", "build", "out"].contains(SourceTree.name(of: relative))
        }
        let found = try SourceTree.files(under: SourceTree.repository, entering: entered).filter { path in
            [".cs", ".csproj", ".props", ".targets", ".sln", ".slnx"].contains { path.hasSuffix($0) }
        }

        XCTAssertEqual(found, [], "a .NET source or project with no host to build it")
    }

    /// The core's tests assert on the patch by the rule it keeps; none keeps a
    /// stored copy of one to compare with, so `lib/StateUI/Core/Tests` holds Swift
    /// alone.
    func testTheCoreTestsKeepNoStoredCopyOfAPatch() throws {
        let root = SourceTree.repository.appendingPathComponent("lib/StateUI/Core/Tests")
        let files = try SourceTree.files(under: root, entering: SourceTree.entersSources)

        XCTAssertGreaterThan(files.count, 50, "the walk read almost nothing")
        XCTAssertEqual(files.filter { !$0.hasSuffix(".swift") }, [], "a stored file beside the tests")
    }

    /// A host calls the library in Swift, in its own process, so the library
    /// exports no C function: a `@_cdecl` in its sources is a door no host
    /// opens. An application's own - the registration its Android head calls
    /// from `JNI_OnLoad` - is the application's.
    func testTheLibraryExportsNoCFunction() throws {
        var read = 0

        for (path, text) in try SourceTree.allSources() {
            read += 1
            let code = text.split(separator: "\n", omittingEmptySubsequences: false)
                .map { $0.drop(while: { $0 == " " }) }
                .filter { !$0.hasPrefix("//") }
                .joined(separator: "\n")

            XCTAssertFalse(code.contains("@_cdecl(\""), "\(path) exports a C function")
        }

        XCTAssertGreaterThan(read, 100, "the walk read almost nothing")
    }

    /// The Android Views host is a Swift package beside AppKit's, with its Java
    /// layer, its tests in a package of their own and the scripts under
    /// `.scripts/Android`; and every native method the Java layer declares is
    /// one the host registers, by name - one left out is found only on a
    /// device, as an `UnsatisfiedLinkError`.
    func testTheAndroidViewsHostIsAHostPackageBesideAppKit() throws {
        let repository = SourceTree.repository
        let host = "lib/StateUI/StateUI.Android"
        for relative in [
            "\(host)/Package.swift", "\(host)/Tests/Package.swift",
            "\(host)/Tests/Platforms/Android/build.gradle.kts",
            "\(host)/Java/stateui/android/StateUIActivity.java",
            ".scripts/Android/build-swift.sh", ".scripts/Android/run-app.sh",
            ".scripts/Android/test-android.sh", ".scripts/Android/devices.sh",
        ] {
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: repository.appendingPathComponent(relative).path),
                "missing \(relative)")
        }

        func names(_ pattern: String, in relative: String) throws -> Set<String> {
            let text = try String(contentsOf: repository.appendingPathComponent(relative), encoding: .utf8)
            let expression = try NSRegularExpression(pattern: pattern)
            return Set(expression.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
                Range($0.range(at: 1), in: text).map { String(text[$0]) }
            })
        }

        let declared = try names(#"static native \w+ (\w+)\("#, in: "\(host)/Java/stateui/android/StateUIHost.java")
        let registered = try names(
            #"\("(\w+)", "\("#, in: "\(host)/Sources/StateUIAndroid/Runtime/StateUIAndroid.swift")
        XCTAssertGreaterThan(declared.count, 3, "the walk read almost no native method")
        XCTAssertEqual(declared, registered, "the Java layer and the host disagree on the native methods")
    }

    /// The WinUI 3 host is a Swift package beside the others, with its C++/WinRT
    /// relay as a C++ target of its own and its scripts under `.scripts/WinUI`;
    /// and every function the relay's header declares is one the relay defines -
    /// a declaration with nothing behind it is found only when a head links.
    func testTheWinUIHostIsAHostPackageBesideTheOthers() throws {
        let repository = SourceTree.repository
        let host = "lib/StateUI/StateUI.WinUI"
        let relay = "\(host)/Sources/CStateUIWinUI"
        for relative in [
            "\(host)/Package.swift", "\(relay)/include/CStateUIWinUI.h",
            ".scripts/WinUI/tools.ps1", ".scripts/WinUI/run-app.ps1", ".scripts/WinUI/test-winui.ps1",
        ] {
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: repository.appendingPathComponent(relative).path),
                "missing \(relative)")
        }

        func names(_ pattern: String, in texts: [String]) throws -> Set<String> {
            let expression = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
            return Set(texts.flatMap { text in
                expression.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
                    Range($0.range(at: 1), in: text).map { String(text[$0]) }
                }
            })
        }

        let header = try String(
            contentsOf: repository.appendingPathComponent("\(relay)/include/CStateUIWinUI.h"), encoding: .utf8)
        let sources = try SourceTree.files(under: repository.appendingPathComponent(relay), entering: { _ in true })
            .filter { $0.hasSuffix(".cpp") }
            .map { try String(contentsOf: repository.appendingPathComponent("\(relay)/\($0)"), encoding: .utf8) }
        let declared = try names(#"^[\w ]+\*? ?(stateui_winui_\w+)\("#, in: [header])
        let defined = try names(#"^extern "C" [\w ]+\*? ?(stateui_winui_\w+)\("#, in: sources)
        XCTAssertGreaterThan(declared.count, 10, "the walk read almost no function of the relay")
        XCTAssertEqual(
            declared.symmetricDifference(defined).sorted(), [],
            "declared by the relay's header or defined by its sources, and not both")
    }

    /// No C++ exception leaves the WinUI relay: every function it gives Swift catches whatever its body throws -
    /// WinUI's, the standard library's, any other - and says it on the host's log, since an exception crossing the C
    /// boundary ends the process where nobody can say why.
    func testNoCppExceptionLeavesTheRelay() throws {
        let relay = SourceTree.repository.appendingPathComponent("lib/StateUI/StateUI.WinUI/Sources/CStateUIWinUI")
        var open: [String] = []
        var functions = 0
        for file in try SourceTree.files(under: relay, entering: { _ in true }) where file.hasSuffix(".cpp") {
            let text = try String(contentsOf: relay.appendingPathComponent(file), encoding: .utf8)
            for function in Self.cFunctions(in: text) {
                functions += 1
                if !function.body.contains("catch (...)") { open.append("\(file): \(function.name)") }
            }
        }

        XCTAssertGreaterThan(functions, 150, "the walk read the relay's functions")
        XCTAssertEqual(open, [], "a C function of the relay lets an exception out")
    }

    /// No exception leaves a handler the relays give WinUI either: WinUI calls it from its own loop, and one leaving
    /// it is stowed and ends the process (a window's activation read as UI Automation closed it, 0xc000027b). Every
    /// handler goes through `guarded`.
    func testNoCppExceptionLeavesARelaysHandler() throws {
        let bare = try NSRegularExpression(pattern: #"(\.[A-Z]\w*|::\w*Handler)\(\s*(winrt::auto_revoke,\s*)?\["#)
        var open: [String] = []
        for folder in ["lib/StateUI/StateUI.WinUI/Sources/CStateUIWinUI", "lib/Backends/WebView.WinUI/Relay"] {
            let root = SourceTree.repository.appendingPathComponent(folder)
            for name in try FileManager.default.contentsOfDirectory(atPath: root.path) where name.hasSuffix(".cpp") {
                let text = try String(contentsOf: root.appendingPathComponent(name), encoding: .utf8)
                for match in bare.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                    let before = text[..<Range(match.range, in: text)!.lowerBound]
                    open.append("\(name):\(before.filter { $0 == "\n" }.count + 1)")
                }
            }
        }
        XCTAssertEqual(open, [], "a handler WinUI calls is not guarded")
    }

    /// Each `extern "C"` function `text` defines: its name, and its body - braces counted outside words, letters and
    /// comments.
    private static func cFunctions(in text: String) -> [(name: String, body: String)] {
        let characters = Array(text)
        let opener = Array("extern \"C\" ")
        var found: [(name: String, body: String)] = []
        var at = 0
        while at + opener.count <= characters.count {
            guard Array(characters[at..<at + opener.count]) == opener, at == 0 || characters[at - 1] == "\n" else {
                at += 1
                continue
            }
            guard let open = characters[at...].firstIndex(of: "(") else { break }
            let name = String(characters[at..<open]).split(separator: " ").last.map(String.init) ?? "?"
            guard let start = characters[open...].firstIndex(where: { $0 == "{" || $0 == ";" }),
                  characters[start] == "{"
            else {
                at = open
                continue
            }
            var depth = 0
            var index = start
            while index < characters.count {
                switch characters[index] {
                case "\"", "'":
                    let quote = characters[index]
                    index += 1
                    while index < characters.count, characters[index] != quote {
                        index += characters[index] == "\\" ? 2 : 1
                    }
                case "/" where index + 1 < characters.count && characters[index + 1] == "/":
                    while index < characters.count, characters[index] != "\n" { index += 1 }
                case "{": depth += 1
                case "}": depth -= 1
                default: break
                }
                if depth == 0 { break }
                index += 1
            }
            found.append((name, String(characters[start...min(index, characters.count - 1)])))
            at = index
        }
        return found
    }

    /// No WinUI script writes into an executable a build linked: the next build would link it again, however
    /// little changed. The Windows App SDK's manifest stands beside each one.
    func testTheWinUIScriptsLeaveWhatABuildLinked() throws {
        let scripts = SourceTree.repository.appendingPathComponent(".scripts/WinUI")
        let tools = try String(contentsOf: scripts.appendingPathComponent("tools.ps1"), encoding: .utf8)
        XCTAssertTrue(tools.contains(#"WriteAllText("$executable.manifest""#), "the manifest stands beside each executable")

        for name in try FileManager.default.contentsOfDirectory(atPath: scripts.path) where name.hasSuffix(".ps1") {
            let text = try String(contentsOf: scripts.appendingPathComponent(name), encoding: .utf8)
            XCTAssertFalse(text.contains("-outputresource"), "\(name) writes into an executable")
        }
    }

    /// A WinRT object a WinUI relay keeps for the process beside WinUI is made with `new` and never destroyed: a
    /// static one is destroyed as the process exits, after WinUI is gone, and Windows ends the process there (a
    /// display watcher did, `RaiseFailFastException` in Microsoft.UI.Windowing.dll on every window's close). The
    /// test thread's WinUI itself - its dispatcher, application and XAML manager - is destroyed then, which is its
    /// shutdown; kept past it, the process ends in an access violation.
    func testTheWinUIRelaysDestroyNoWinRTObjectAtExit() throws {
        let kept = try NSRegularExpression(
            pattern: #"^\s+static\s+(const\s+)?(auto|winrt::|xaml::|controls::|media::|power::)(?!.*\bnew\b)"#,
            options: [.anchorsMatchLines])
        var found: [String] = []
        for folder in ["lib/StateUI/StateUI.WinUI/Sources/CStateUIWinUI", "lib/Backends/WebView.WinUI/Relay"] {
            let root = SourceTree.repository.appendingPathComponent(folder)
            for name in try FileManager.default.contentsOfDirectory(atPath: root.path) where name.hasSuffix(".cpp") {
                let text = try String(contentsOf: root.appendingPathComponent(name), encoding: .utf8)
                for match in kept.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                    let at = Range(match.range, in: text)!.lowerBound
                    let line = text[at...].prefix { $0 != "\n" }
                    guard !Self.winUIItself.contains(where: { line.contains($0) }) else { continue }
                    found.append("\(name):\(text[..<at].filter { $0 == "\n" }.count + 1)")
                }
            }
        }
        XCTAssertEqual(found.sorted(), [], "a WinRT object destroyed at exit")
    }

    /// What makes the test thread's WinUI, which shuts down as its statics are destroyed.
    private static let winUIItself = [
        "DispatcherQueueController::CreateOnCurrentThread", "make<StateUIApplication>",
        "WindowsXamlManager::InitializeForCurrentThread",
    ]

    /// What a backend's engine needs beside a WinUI application is the backend's to lay there, and only beside an
    /// application linking it: the host's scripts name no file of WebView2's, and the web view's backend lays them
    /// where its library stands.
    func testAWinUIBackendLaysItsOwnFilesBesideTheApplication() throws {
        let repository = SourceTree.repository
        let tools = try String(contentsOf: repository.appendingPathComponent(".scripts/WinUI/tools.ps1"), encoding: .utf8)
        for file in ["Microsoft.Web.WebView2.Core.dll", "WebView2Loader.dll"] {
            XCTAssertFalse(tools.contains(file), "tools.ps1 lays \(file) beside every application")
        }
        let backend = repository.appendingPathComponent("lib/Backends/WebView.WinUI/SelfContained.ps1")
        let text = (try? String(contentsOf: backend, encoding: .utf8)) ?? ""
        XCTAssertTrue(text.contains("StateUIWebViewWinUI.dll"), "the backend lays nothing, or beside every application")
        XCTAssertTrue(text.contains("WebView2Loader.dll"), "the backend lays no loader")
    }

    /// Every WINUI HEAD is an executable its application declares exactly when a
    /// build says it is a WinUI one, linked as a windowed application - started by
    /// itself it opens no console - whose main names the application to the host
    /// and hands it the thread.
    func testEveryWinUIHeadRunsTheApplicationsModule() throws {
        var heads = 0

        for application in try SourceTree.applications() {
            let head = application.appendingPathComponent("Platforms/WinUI")
            guard FileManager.default.fileExists(atPath: head.path) else { continue }
            heads += 1
            let name = application.lastPathComponent
            func text(_ relative: String) throws -> String {
                try String(contentsOf: application.appendingPathComponent(relative), encoding: .utf8)
            }

            XCTAssertTrue(
                declaresHead(try text("Package.swift"), of: name, for: "WinUI", in: "Platforms/WinUI"),
                "\(name)'s Package.swift declares no WinUI head in Platforms/WinUI")

            let entry = try text("Platforms/WinUI/main.swift")
            for shape in ["import StateUIWinUI", "stateui_app_register()", "StateUIWinUI.run()"] {
                XCTAssertTrue(entry.contains(shape), "\(name)'s WinUI head does not say \(shape)")
            }
        }

        XCTAssertGreaterThan(heads, 0, "no WinUI head found")
    }

    /// The conformance suite is a package of its own that links the one StateUI runtime as
    /// its product, and none of its sources names a toolkit: what it asserts is what executing the contract does, on
    /// every host.
    func testTheConformanceSuiteNamesNoToolkit() throws {
        let package = SourceTree.repository.appendingPathComponent("lib/StateUI/StateUI.Conformance")
        let manifest = try String(contentsOf: package.appendingPathComponent("Package.swift"), encoding: .utf8)
        XCTAssertTrue(manifest.contains(#".product(name: "StateUI", package: "StateUIRoot")"#), "StateUI linked as a product")
        XCTAssertFalse(manifest.contains(#"dependencies: ["StateUI"]"#), "a second StateUI runtime")

        let sources = package.appendingPathComponent("Sources")
        let files = try SourceTree.files(under: sources, entering: { _ in true }).filter { $0.hasSuffix(".swift") }
        XCTAssertGreaterThan(files.count, 10, "the walk read almost nothing")
        let toolkit = try NSRegularExpression(
            pattern: #"GTK|WinUI|AppKit|UIKit|Android|\bNS[A-Z]\w+|\bgtk_|\badw_|stateui_winui_|Java\b"#)
        for file in files {
            let text = try String(contentsOf: sources.appendingPathComponent(file), encoding: .utf8)
            for match in toolkit.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                let line = text[..<Range(match.range, in: text)!.lowerBound].split(separator: "\n", omittingEmptySubsequences: false).count
                XCTFail("\(file):\(line) names a toolkit: \((text as NSString).substring(with: match.range))")
            }
        }
    }

    /// Every host whose suite runs the conformance cases runs every family of them - one a contract, whole or in
    /// every one of its parts: a family one host leaves out is a column of the dictionary that host silently never
    /// marks.
    func testEveryHostRunsEveryConformanceFamily() throws {
        let repository = SourceTree.repository
        let cases = repository.appendingPathComponent("lib/StateUI/StateUI.Conformance/Sources/Contract")
        let family = try NSRegularExpression(pattern: #"public enum (\w+): ConformanceFamily"#)
        var families: Set<String> = []
        for file in try SourceTree.files(under: cases, entering: { _ in true }) {
            let text = try String(contentsOf: cases.appendingPathComponent(file), encoding: .utf8)
            for match in family.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                families.insert((text as NSString).substring(with: match.range(at: 1)))
            }
        }
        XCTAssertGreaterThanOrEqual(families.count, 70, "the walk found almost no family")

        let lib = repository.appendingPathComponent("lib")
        let runners = try SourceTree.files(
            under: lib, entering: { !$0.contains(".build") && !$0.hasPrefix("StateUI/Core/") })
            .filter { $0.hasSuffix("ConformanceTests.swift") }
        XCTAssertFalse(runners.isEmpty, "no host runs the conformance cases")
        for runner in runners {
            let text = try String(contentsOf: lib.appendingPathComponent(runner), encoding: .utf8)
            for name in families.sorted() {
                let part = try NSRegularExpression(
                    pattern: #"conform\(\#(name)\.self, part: Conformance\.Part\((\d+), of: (\d+)\)\)"#)
                let parts = part.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { match in
                    (Int((text as NSString).substring(with: match.range(at: 1))) ?? 0,
                     Int((text as NSString).substring(with: match.range(at: 2))) ?? 0)
                }
                if parts.isEmpty, !text.contains("conform(\(name).self)") {
                    XCTFail("\(runner) does not run the family \(name)")
                } else if let count = parts.first?.1, Set(parts.map(\.0)) != Set(1...count) || parts.contains(where: { $0.1 != count }) {
                    XCTFail("\(runner) runs the family \(name) in parts that are not each of 1 to \(count)")
                }
            }
        }
    }

    /// The GTK 4 host is a Swift package beside the others, Swift alone over GTK's C API: its C module is
    /// the system's headers and nothing else - a module map and one header that includes libadwaita's and names
    /// GLib's flags, each under a name of the host's - and its scripts stand under `.scripts/GTK`.
    func testTheGTKHostIsSwiftAloneOverGTKsCAPI() throws {
        let repository = SourceTree.repository
        let host = "lib/StateUI/StateUI.GTK"
        let module = "\(host)/Sources/CStateUIGTK"
        for relative in ["\(host)/Package.swift", ".scripts/GTK/run-app.sh"] {
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: repository.appendingPathComponent(relative).path),
                "missing \(relative)")
        }

        let files = try SourceTree.files(under: repository.appendingPathComponent(module), entering: { _ in true })
        XCTAssertEqual(files.sorted(), ["CStateUIGTK.h", "module.modulemap"], "the C module holds more than the headers")

        let header = try String(contentsOf: repository.appendingPathComponent("\(module)/CStateUIGTK.h"), encoding: .utf8)
        let code = header.split(separator: "\n").filter { !$0.hasPrefix("//") && !$0.isEmpty }
        XCTAssertEqual(code.first, "#include <adwaita.h>")
        // A flag GLib 2.86 hides from Swift, typed as GLib's own and given its value: nothing of the host's.
        let flag = try Regex(#"^static const G[A-Za-z]+ STATEUI_[A-Z_]+ = G_[A-Z_]+;$"#)
        XCTAssertEqual(
            code.dropFirst().filter { (try? flag.wholeMatch(in: String($0))) == nil }, [],
            "the header declares something of its own")
    }

    /// Every GTK HEAD is an executable its application declares exactly when a
    /// build says it is a GTK one, whose main names the application to the host
    /// and hands it the thread under the application's name.
    func testEveryGTKHeadRunsTheApplicationsModule() throws {
        var heads = 0

        for application in try SourceTree.applications() {
            let head = application.appendingPathComponent("Platforms/GTK")
            guard FileManager.default.fileExists(atPath: head.path) else { continue }
            heads += 1
            let name = application.lastPathComponent
            func text(_ relative: String) throws -> String {
                try String(contentsOf: application.appendingPathComponent(relative), encoding: .utf8)
            }

            XCTAssertTrue(
                declaresHead(try text("Package.swift"), of: name, for: "GTK", in: "Platforms/GTK"),
                "\(name)'s Package.swift declares no GTK head in Platforms/GTK")

            let entry = try text("Platforms/GTK/main.swift")
            for shape in ["import StateUIGTK", "stateui_app_register()", "StateUIGTK.run(applicationID: \"com.stateui."] {
                XCTAssertTrue(entry.contains(shape), "\(name)'s GTK head does not say \(shape)")
            }
        }

        XCTAssertGreaterThan(heads, 0, "no GTK head found")
    }

    /// Every ANDROID HEAD is a library Android loads, declared by the
    /// application's manifest exactly when a build says it is an Android one:
    /// its Gradle build, an Android manifest naming the host's activity - or one
    /// extending it - and the head's library, and a `JNI_OnLoad` that names the application to the host.
    func testEveryAndroidHeadLoadsTheApplicationsModule() throws {
        var heads = 0

        for application in try SourceTree.applications() {
            let head = application.appendingPathComponent("Platforms/Android")
            guard FileManager.default.fileExists(atPath: head.path) else { continue }
            heads += 1
            let name = application.lastPathComponent
            func text(_ relative: String) throws -> String {
                try String(contentsOf: application.appendingPathComponent(relative), encoding: .utf8)
            }

            XCTAssertTrue(
                declaresHead(try text("Package.swift"), of: name, for: "Android", in: "Platforms/Android/Swift"),
                "\(name)'s Package.swift declares no Android head in Platforms/Android/Swift")

            // The host's activity, or one of the application's own Java that extends it.
            let android = try text("Platforms/Android/AndroidManifest.xml")
            let activity = android.components(separatedBy: "<activity").dropFirst().first?
                .components(separatedBy: "android:name=\"").dropFirst().first?
                .components(separatedBy: "\"").first ?? ""
            if activity != "stateui.android.StateUIActivity" {
                let source = "Platforms/Android/Java/" + activity.replacingOccurrences(of: ".", with: "/") + ".java"
                XCTAssertTrue(
                    (try? text(source))?.contains("extends StateUIActivity") == true,
                    "\(name)'s activity \(activity) is neither the host's nor one extending it")
            }
            XCTAssertTrue(android.contains("android:value=\"\(name)Android\""))

            let entry = try text("Platforms/Android/Swift/\(name)Android.swift")
            for shape in ["@_cdecl(\"JNI_OnLoad\")", "stateui_app_register()", "StateUIAndroid.load("] {
                XCTAssertTrue(entry.contains(shape), "\(name)'s Android head does not say \(shape)")
            }

            XCTAssertTrue(try text("Platforms/Android/build.gradle.kts").contains("stated(\"stateui.libraries\")"))
        }

        XCTAssertGreaterThan(heads, 0, "no Android head found")
    }

    /// The code every host runs names no host. Swift written for one host alone
    /// stands under the condition named for it - `#if APPKIT`, which every
    /// AppKit build of an application defines; see the two tests below - and
    /// Swift for several, under their conditions joined, `#if APPKIT || GTK`.
    /// Such a block, up to its `#else` or `#endif`, is the one place the
    /// library and each application's `Sources/` may name those hosts. A host
    /// with no builds any more is named nowhere, under no condition.
    ///
    /// The words are assembled here so this guard does not find itself.
    func testTheSharedSourcesNameAHostOnlyUnderItsCondition() throws {
        let repository = SourceTree.repository
        var roots = [repository.appendingPathComponent("lib/StateUI/Core/Sources")]
        let apps = try FileManager.default.contentsOfDirectory(
            at: repository.appendingPathComponent("apps"), includingPropertiesForKeys: nil)
        roots += apps.map { $0.appendingPathComponent("Sources") }

        var offenders: [String] = []
        for (word, conditioned) in [("app" + "kit", true), ("win" + "ui", true), ("gt" + "k", true), ("ma" + "ui", false)] {
            // A block for this host: its condition alone, or joined with other hosts' by `||`.
            func opens(_ directive: String) -> Bool {
                guard directive.hasPrefix("#if ") else { return false }
                return directive.dropFirst(4).components(separatedBy: "||")
                    .map { $0.trimmingCharacters(in: .whitespaces) }.contains(word.uppercased())
            }
            for root in roots {
                guard let walk = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
                else { continue }

                for case let file as URL in walk where file.pathExtension == "swift" {
                    let text = try String(contentsOf: file, encoding: .utf8)
                    // Zero outside the condition's block, one directly inside
                    // it, more inside a block nested in it.
                    var depth = 0
                    for (number, line) in text.split(separator: "\n", omittingEmptySubsequences: false)
                        .enumerated() {
                        let directive = line.trimmingCharacters(in: .whitespaces)
                        if depth > 0 {
                            if directive.hasPrefix("#if") {
                                depth += 1
                            } else if directive.hasPrefix("#endif") {
                                depth -= 1
                            } else if depth == 1 && directive.hasPrefix("#else") {
                                // What follows is compiled for every other host.
                                depth = 0
                            }
                            continue
                        }

                        if conditioned && opens(directive) {
                            depth = 1
                        } else if line.lowercased().contains(word) {
                            let relative = String(file.path.dropFirst(repository.path.count + 1))
                            offenders.append("\(relative):\(number + 1)")
                        }
                    }
                }
            }
        }

        XCTAssertEqual(offenders, [], "these name a host in code every host runs")
    }

    /// Every application DEFINES ITS HOST'S CONDITION IN ITS MANIFEST, for
    /// every module it compiles, exactly when a build says it is for that host.
    ///
    /// One variable says both things - `STATEUI_HOST=appkit` gives the build an
    /// AppKit head and compiles the code under `#if APPKIT` - so a build and an
    /// editor that set it agree, and the editor completes that code like any
    /// other. The flag it replaced, `-Xswiftc -DAPPKIT`, is refused wherever a
    /// build is written down: a second spelling of the same switch is how the
    /// two drift apart.
    func testEveryApplicationDefinesItsHostsConditionInItsManifest() throws {
        let repository = SourceTree.repository
        func text(_ relative: String) throws -> String {
            try String(contentsOf: repository.appendingPathComponent(relative), encoding: .utf8)
        }

        for relative in ["apps/Gallery/Package.swift", "apps/HelloWorld/Package.swift"] {
            let manifest = try text(relative)

            for shape in [
                "$0.lowercased() == Context.environment[\"STATEUI_HOST\"]", ".define($0.uppercased())",
            ] {
                XCTAssertTrue(manifest.contains(shape), "\(relative) does not say \(shape)")
            }

            // No module is left compiling without it.
            let settings = manifest.components(separatedBy: "swiftSettings:").dropFirst()
            XCTAssertFalse(settings.isEmpty, "\(relative) declares no target")
            for setting in settings {
                XCTAssertTrue(
                    setting.trimmingCharacters(in: .whitespaces).hasPrefix("settings"),
                    "\(relative) compiles a module with settings of its own")
            }
        }

        for relative in [
            ".scripts/AppKit/build-gallery-appkit.sh", ".scripts/new-app.sh", ".scripts/test-native.sh",
            "docs/development.md", "docs/getting-started.md",
        ] {
            let commands = try text(relative)
                .replacingOccurrences(of: "\\\n", with: " ")
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { Self.runsSwift($0) }

            for command in commands {
                XCTAssertFalse(
                    command.contains("-DAPPKIT"),
                    "\(relative) still gives -DAPPKIT, which the manifest now defines: \(command)")
            }
        }

        XCTAssertFalse(
            try text(".vscode/tasks.json").contains("\"-DAPPKIT\""),
            ".vscode/tasks.json still gives -DAPPKIT, which the manifest now defines")
    }

    /// Whether a line RUNS SwiftPM, read past any variables it sets first.
    ///
    /// An AppKit head needs one set - see the test below - and a command that
    /// sets it inline is still that command, so the name is looked for after
    /// each leading `NAME=value`. Without this, prefixing a command would drop
    /// it out of the list above and the guard would stop asking anything of it.
    private static func runsSwift(_ line: String) -> Bool {
        var rest = line

        while let space = rest.firstIndex(of: " ") {
            let first = String(rest[rest.startIndex..<space])

            guard first.contains("="), !first.contains("/"), !first.contains("\"") else { break }

            rest = String(rest[rest.index(after: space)...]).trimmingCharacters(in: .whitespaces)
        }

        return rest.hasPrefix("swift build") || rest.hasPrefix("swift run")
            || rest.contains("$(swift build")
    }

    /// Every build of an application's AppKit head TELLS ITS MANIFEST there is
    /// one.
    ///
    /// An application declares that target, the product it makes and the
    /// StateUIHead dependency only when `STATEUI_HOST` is `appkit`, so that
    /// `swift test` compiles no part of one host's half. A build that leaves
    /// the variable out asks for a product the manifest never declared, and a
    /// page that leaves it out hands a reader a command that cannot work.
    ///
    /// Asked of the FILE rather than of each command, because a script may
    /// export it once above the builds it runs.
    func testEveryAppKitBuildTellsTheManifestItHasAnAppKitHead() throws {
        let repository = SourceTree.repository
        func text(_ relative: String) throws -> String {
            try String(contentsOf: repository.appendingPathComponent(relative), encoding: .utf8)
        }

        for relative in [
            ".scripts/AppKit/build-gallery-appkit.sh", ".scripts/new-app.sh", ".scripts/test-native.sh",
            "docs/development.md", "docs/getting-started.md",
        ] {
            XCTAssertTrue(
                try text(relative).contains("STATEUI_HOST=appkit"),
                "\(relative) builds an AppKit head without telling the manifest there is one")
        }

        // A task sets it in the environment it runs the build in.
        let tasks = try text(".vscode/tasks.json").components(separatedBy: "\"label\"").filter { task in
            let lines = task.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            guard let product = lines.firstIndex(of: "\"--product\","), product + 1 < lines.count
            else { return false }
            return lines[product + 1].hasSuffix("AppKit\"")
        }

        XCTAssertFalse(tasks.isEmpty, ".vscode/tasks.json builds no AppKit head")

        for task in tasks {
            XCTAssertTrue(
                task.contains("\"STATEUI_HOST\": \"appkit\""),
                ".vscode/tasks.json builds an AppKit head without telling the manifest there is one")
        }
    }

    /// A build names its host by ONE variable, `STATEUI_HOST=<host>`. The five
    /// it replaced, one a host and each set to 1, let a build be two hosts at
    /// once - an inherited one beside a script's own - and the manifests took
    /// the first. No script, manifest, page, task or editor source writes one
    /// again.
    func testABuildNamesItsHostByOneVariable() throws {
        let removed = try NSRegularExpression(pattern: "STATEUI_(APP" + "KIT|UI" + "KIT|AND" + "ROID|WIN" + "UI|G" + "TK)(?![A-Z_])")
        let kinds: Set<String> = ["swift", "md", "yml", "sh", "ps1", "json", "kts", "ts"]
        let skipped: Set<String> = [
            ".build", ".git", ".gradle", ".sourcekit-lsp", "node_modules", "out", "exports", "bin", "obj", "artifacts",
        ]
        let files = try SourceTree.files(under: SourceTree.repository, entering: { relative in
            !skipped.contains(String(relative.split(separator: "/").last ?? ""))
        }).filter { kinds.contains(URL(fileURLWithPath: $0).pathExtension) }
        XCTAssertGreaterThan(files.count, 100, "the walk read almost no file")

        var offenders: [String] = []
        for relative in files {
            let text = try String(contentsOf: SourceTree.repository.appendingPathComponent(relative), encoding: .utf8)
            if removed.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
                offenders.append(relative)
            }
        }
        XCTAssertEqual(offenders, [], "these name a host by a variable of its own, not STATEUI_HOST")
    }

    /// Every Android head shows the application's icon: the launcher's adaptive icon, drawn from
    /// `Resources/AppIcon` - the ground and the mark - as the head is built, and named in its manifest.
    func testEveryAndroidHeadShowsTheApplicationsIcon() throws {
        var heads = 0

        for application in try SourceTree.applications() {
            let head = application.appendingPathComponent("Platforms/Android")
            guard FileManager.default.fileExists(atPath: head.path) else { continue }
            heads += 1
            let name = application.lastPathComponent

            let manifest = try String(contentsOf: head.appendingPathComponent("AndroidManifest.xml"), encoding: .utf8)
            for shape in ["android:icon=\"@mipmap/appicon\"", "android:roundIcon=\"@mipmap/appicon\""] {
                XCTAssertTrue(manifest.contains(shape), "\(name)'s Android manifest does not say \(shape)")
            }
            let gradle = try String(contentsOf: head.appendingPathComponent("build.gradle.kts"), encoding: .utf8)
            XCTAssertTrue(gradle.contains("res.srcDir(stated(\"stateui.res\"))"), "\(name)'s head takes no drawn icon")
            for artwork in ["appicon_bkg.svg", "appicon_mark.svg"] {
                XCTAssertTrue(
                    FileManager.default.fileExists(
                        atPath: application.appendingPathComponent("Resources/AppIcon/\(artwork)").path),
                    "\(name) has no Resources/AppIcon/\(artwork) to draw its Android icon from")
            }
        }

        XCTAssertGreaterThan(heads, 0, "no Android head found")
        let tools = try String(
            contentsOf: SourceTree.repository.appendingPathComponent(".scripts/Android/tools.sh"), encoding: .utf8)
        XCTAssertTrue(
            tools.contains("draw-app-icon") && tools.contains("-Pstateui.res="),
            "an Android head is built without its icon being drawn")
    }

    /// Every Android head may read the network: the host reports it to the application's views, and a head
    /// whose manifest does not ask reports it unknown for good, with nothing said anywhere.
    func testEveryAndroidHeadMayReadTheNetwork() throws {
        let permission = "<uses-permission android:name=\"android.permission.ACCESS_NETWORK_STATE\" />"
        let heads = try SourceTree.applications().map { $0.appendingPathComponent("Platforms/Android") }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            + [SourceTree.repository.appendingPathComponent("lib/StateUI/StateUI.Android/Tests/Platforms/Android")]

        XCTAssertGreaterThan(heads.count, 1, "no Android head found")
        for head in heads {
            let manifest = try String(contentsOf: head.appendingPathComponent("AndroidManifest.xml"), encoding: .utf8)
            XCTAssertTrue(manifest.contains(permission), "\(head.path) does not ask for ACCESS_NETWORK_STATE")
        }
    }

    /// Every application's AppKit head hands the host its icon on macOS's icon
    /// grid, found from its own source file rather than from the directory it
    /// was started in.
    ///
    /// A macOS icon is a 1024 canvas whose body is an 824-point rounded square
    /// 100 points in: artwork drawn edge to edge stands larger in the Dock than
    /// every icon beside it. And a head started by a debugger, a task or a
    /// terminal elsewhere would find no artwork at all, and show the bare
    /// executable's icon.
    func testEveryAppKitHeadShowsAnIconOnTheMacGridWhereverItIsStarted() throws {
        let applications = try SourceTree.applications()
        let icon = "Resources/AppIcon/appicon_macos.svg"
        var heads = 0

        for application in applications {
            let head = application.appendingPathComponent("Platforms/AppKit/main.swift")
            guard FileManager.default.fileExists(atPath: head.path) else { continue }
            heads += 1

            let relative = application.path.replacingOccurrences(of: SourceTree.repository.path + "/", with: "")
            let text = try String(contentsOf: head, encoding: .utf8)

            XCTAssertTrue(
                text.contains("applicationIcon:") && text.contains("appicon_macos.svg"),
                "\(relative)'s AppKit head does not hand the host \(icon)")
            XCTAssertFalse(
                text.contains("currentDirectoryPath"),
                "\(relative)'s AppKit head finds its artwork from the directory it was started in")

            let artwork = try String(contentsOf: application.appendingPathComponent(icon), encoding: .utf8)
            XCTAssertTrue(
                artwork.contains("viewBox=\"0 0 1024 1024\"")
                    && artwork.contains("x=\"100\" y=\"100\" width=\"824\" height=\"824\""),
                "\(relative)/\(icon) is not on macOS's icon grid: an 824 body, 100 in, on a 1024 canvas")
        }

        XCTAssertGreaterThan(heads, 1, "no AppKit head found")
        XCTAssertTrue(
            try String(
                contentsOf: SourceTree.repository.appendingPathComponent(".scripts/AppKit/build-gallery-appkit.sh"),
                encoding: .utf8
            ).contains("Resources/AppIcon/appicon_macos.svg"),
            "the Gallery's bundle makes its .icns from artwork off macOS's icon grid")
    }

    /// Every application's GTK head has its icon on GNOME's icon grid, which the run script installs, with the
    /// desktop's entry, under the application's ID - the name GNOME finds a window's icon by.
    ///
    /// A GNOME app icon is a 128 canvas whose square body is 96 pixels, 16 in from each side, on a base 4
    /// pixels deep: artwork drawn edge to edge stands larger than every icon beside it.
    func testEveryGTKHeadShowsAnIconOnTheGNOMEGrid() throws {
        let icon = "Resources/AppIcon/appicon_gnome.svg"
        var heads = 0

        for application in try SourceTree.applications() {
            guard FileManager.default.fileExists(
                atPath: application.appendingPathComponent("Platforms/GTK/main.swift").path)
            else { continue }
            heads += 1

            let relative = application.path.replacingOccurrences(of: SourceTree.repository.path + "/", with: "")
            let artwork = try String(contentsOf: application.appendingPathComponent(icon), encoding: .utf8)
            XCTAssertTrue(
                artwork.contains("viewBox=\"0 0 128 128\"")
                    && artwork.contains("x=\"16\" y=\"12\" width=\"96\" height=\"96\""),
                "\(relative)/\(icon) is not on GNOME's icon grid: a 96 body, 16 in, on a 128 canvas")
        }

        XCTAssertGreaterThan(heads, 1, "no GTK head found")
        let script = try String(
            contentsOf: SourceTree.repository.appendingPathComponent(".scripts/GTK/run-app.sh"), encoding: .utf8)
        for installed in ["appicon_gnome.svg", "/apps/$application_id.svg", "Icon=$application_id"] {
            XCTAssertTrue(script.contains(installed), "the GTK run script does not install \(installed)")
        }
    }

    func testGalleryOwnsItsAcceptanceTests() {
        let repository = SourceTree.repository

        XCTAssertTrue(FileManager.default.fileExists(
            atPath: repository.appendingPathComponent("apps/Gallery/Tests/GalleryTests").path))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: repository.appendingPathComponent("lib/Tests").path))
    }
}
