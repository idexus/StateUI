// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

/// The Web host's suite: `lib/StateUI/StateUI.Web/Testing` built for WebAssembly, its facade held to its API record,
/// the host's own tests run in Node over a page with just enough of a DOM, then - in a browser's own page, headless -
/// the conformance families and the host's tests that need its layout, focus, dialogs and input.
/// Design: docs/design/tooling/repository.md#the-web-hosts-suite
struct WebSuite {
    let checkout: URL
    let tools: ToolResolver
    /// Whether the API phase writes its records rather than holds them.
    var recordingAPI = false

    /// The host's own test classes that need a browser's own page: they run a host.
    static let inBrowser = [
        "WebDrawnChildrenTests",
        "WebGesturePaceTests",
        "WebRequestTests",
        "WebShapeRoomTests",
        "WebKeyboardTests",
        "WebFrameReportTests",
        "WebWindowClosingTests",
        "WebHistoryTests",
        "WebLinksTests",
        "WebTabTitleTests",
        "WebLeaveTests",
        // Before WebLookTests, whose page holds a desktop's pointer after a touch screen's run.
        "WebTouchScreenTests",
        "WebLookTests",
        "WebRelayWritesTests",
        "WebScrollOffsetTests",
        "WebHandTests",
        "WebPointerTests",
        "WebTabStripTests",
        "WebPageElementTests",
        "WebCanvasViewTests",
        "WebEnvironmentTests",
        "WebToggleTests",
        "WebChoiceTests",
        "WebEditMenuTests",
        "WebTestWindowTests",
        "WebLongPressMenuTests",
        "WebWordsOnTheWayTests",
        "WebScreenReaderTests",
        "WebItemCellTests",
        "WebItemsViewTests",
        "WebVocabularyTests",
        "WebWakeTests",
        "WebBoxBlurTests",
        "WebTextRunsTests",
        "WebDriverBarMenuTests",
        "WebDriverAimTests",
    ]

    private var testing: URL { checkout.appendingPathComponent("lib/StateUI/StateUI.Web/Testing") }
    private var relay: String { checkout.appendingPathComponent("lib/StateUI/StateUI.Web/JavaScript/stateui-web.js").path }

    func run(filter: String?, environment: ProcessEnvironment, reporter: BuildReporter) async throws -> [SuiteResult.Phase] {
        let target = try await BuildTarget.web(compiler: tools.swift, configuration: .debug)
        guard let sdk = target.webSDK else { throw ToolingError(.internalError, "The Web target named no Swift SDK.") }
        let scratch = testing.appendingPathComponent(".build/web")
        // The tests' archive only gains members: one of a source since renamed or gone would link twice. Made anew.
        try? FileManager.default.removeItem(at: scratch.appendingPathComponent("out/Products/Debug-webassembly-wasm32/libStateUIWebTests.a"))
        let common = ["--package-path", testing.path, "--scratch-path", scratch.path, "--swift-sdk", sdk]
        let building = environment
        reporter.progress("building the Web host's tests")
        let built = try await ProcessRunner().run(
            ProcessRequest(tools.swift, arguments: ["build", "--build-tests"] + common, environment: building), output: reporter.output)
        try Task.checkCancellation()
        guard built.succeeded else { return [SuiteResult.Phase(name: "tests", passed: false)] }
        let products = try await ProductFolder.of(tools.swift, placing: common, environment: building).path

        var phases = [SuiteResult.Phase(name: "api StateUIWeb", passed: try await recordAPI(sdk: sdk, products: products, environment: environment, reporter: reporter))]
        let program = "\(products)/StateUIWebTests-test-runner.wasm"
        let runner = testing.appendingPathComponent("JavaScript").path
        let listed = (await ToolOutput.standardOutput(.name("node"), ["\(runner)/run.mjs", relay, program, "--list-tests"]) ?? "")
            .split(separator: "\n").map(String.init).filter { $0.hasPrefix("StateUIWebTests.") }
        let (inNode, inBrowser) = Self.split(listed, filter: filter)
        if !inNode.isEmpty {
            reporter.progress("running the Web host's tests in Node")
            phases.append(SuiteResult.Phase(name: "tests in Node", passed: try await node(
                ["\(runner)/run.mjs", relay, program, inNode.joined(separator: ",")], environment, reporter)))
        }
        if !inBrowser.isEmpty {
            guard let browser = await Self.chromium(environment: environment) else {
                throw ToolingError(.missingToolchain, "The Web host's browser tests need Google Chrome or Chromium; STATEUI_BROWSER names another.")
            }
            reporter.progress("running the conformance families and the host's browser tests in \(URL(fileURLWithPath: browser).lastPathComponent)")
            phases.append(SuiteResult.Phase(name: "tests in a browser", passed: try await node(
                ["\(runner)/run-in-browser.mjs", browser, program, inBrowser.joined(separator: ",")], environment, reporter)))
        }
        return phases
    }

    /// The tests `listed` split where they run - the browser's the conformance families and the host's classes that
    /// need one, Node's the rest - or, `filter`ed, the class, test or family it names where it belongs.
    static func split(_ listed: [String], filter: String?) -> (node: [String], browser: [String]) {
        let conformance = "StateUIWebTests.WebConformanceTests"
        let browserClasses = [conformance] + inBrowser.map { "StateUIWebTests.\($0)" }
        let needsBrowser = { (test: String) in browserClasses.contains { test == $0 || test.hasPrefix($0 + "/") } }
        guard let filter else {
            return (listed.filter { !needsBrowser($0) }, listed.filter { $0.hasPrefix(conformance + "/") } + inBrowser.map { "StateUIWebTests.\($0)" })
        }
        var node: [String] = []
        var browser: [String] = []
        for name in filter.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces) }) where !name.isEmpty {
            // A family's name selects its test, or each of its parts: `testVisualElement1`, …
            let family = listed.filter { test in
                test.hasPrefix("\(conformance)/test\(name)") && test.dropFirst("\(conformance)/test\(name)".count).allSatisfy(\.isNumber)
            }
            let named = name.hasPrefix("StateUIWebTests.") ? name : "StateUIWebTests.\(name)"
            if !family.isEmpty { browser += family } else if needsBrowser(named) { browser.append(named) } else { node.append(named) }
        }
        return (node, browser)
    }

    /// Google Chrome or Chromium, as the browser tests drive them over DevTools - or the one `STATEUI_BROWSER` names.
    static func chromium(environment: ProcessEnvironment) async -> String? {
        if let named = ProcessInfo.processInfo.environment["STATEUI_BROWSER"], !named.isEmpty { return named }
        for path in ["/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", "/Applications/Chromium.app/Contents/MacOS/Chromium"]
            where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        let search = SearchPath(environment: ProcessInfo.processInfo.environment)
        return ["google-chrome", "google-chrome-stable", "chromium", "chromium-browser"].lazy.compactMap { search.find($0)?.path }.first
    }

    private func node(_ arguments: [String], _ environment: ProcessEnvironment, _ reporter: BuildReporter) async throws -> Bool {
        let outcome = try await ProcessRunner().run(ProcessRequest(.name("node"), arguments: arguments, environment: environment), output: reporter.output)
        try Task.checkCancellation()
        return outcome.succeeded
    }

    /// The facade the WebAssembly build made, held to its API record.
    private func recordAPI(sdk: String, products: String, environment: ProcessEnvironment, reporter: BuildReporter) async throws -> Bool {
        let shown = await ToolOutput.text(tools.swift, ["sdk", "configure", "--show-configuration", sdk]) ?? ""
        let value = { (key: String) in
            shown.split(separator: "\n").first { $0.hasPrefix("\(key): ") }.map { String($0.dropFirst(key.count + 2)) } ?? ""
        }
        let map = checkout.appendingPathComponent("lib/StateUI/StateUI.Web/Sources/CStateUIWeb/module.modulemap").path
        let held = environment.forAPIRecord(recording: recordingAPI).setting("STATEUI_API_MODULE", to: "StateUIWeb")
            .setting("STATEUI_API_MODULES", to: products).setting("STATEUI_API_TRIPLE", to: "wasm32-unknown-wasip1")
            .setting("STATEUI_API_SDK", to: value("sdkRootPath"))
            .setting("STATEUI_API_ARGUMENTS", to: ["-resource-dir", value("swiftResourcesPath"), "-Xcc", "-fmodule-map-file=\(map)"].joined(separator: "\n"))
        let outcome = try await ProcessRunner().run(ProcessRequest(tools.swift, arguments: [
            "test", "--package-path", checkout.path, "--filter", "APISurfaceTests/testTheModuleAHostsScriptNamesIsItsRecord",
        ], environment: held), output: reporter.output)
        try Task.checkCancellation()
        return outcome.succeeded
    }
}
