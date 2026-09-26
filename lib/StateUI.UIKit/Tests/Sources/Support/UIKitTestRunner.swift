// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import ObjectiveC
import UIKit
import XCTest
@_spi(Host) import StateUIHost

/// The application the tests run in: once its first scene connects, every test of this module whose "Case.test"
/// name holds one of `STATEUI_FILTER`'s names runs on the main thread, one a turn of the main run loop, each said as
/// it ends; the process ends with the report.
/// Design: docs/design/platforms/uikit/conformance.md#an-application-of-tests
@main
@MainActor
enum UIKitTestRunner {
    static func main() {
        exit(UIApplicationMain(
            CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(UIKitTestApplicationDelegate.self)))
    }

    private static let progress = HostLog(host: "UIKit")
    private static var planned: [(title: String, test: XCTest)] = []
    private static var count = 0
    private static var executed = 0
    private static var failed = 0

    /// Plans the run in `scene`, the one every test's windows stand in, and starts it.
    static func begin(in scene: UIWindowScene) {
        TestScene.scene = scene
        let filter = ProcessInfo.processInfo.environment["STATEUI_FILTER"] ?? ""
        let names = filter.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        planned = testCases().flatMap { testCase in
            XCTestSuite(forTestCaseClass: testCase).tests.map { (title: title(of: $0), test: $0) }
        }
        .filter { item in names.isEmpty || names.contains { item.title.contains($0) } }
        count = planned.count
        next()
    }

    /// Runs the next item in a turn of its own, so what a test left for the main queue runs before the one after.
    private static func next() {
        RunLoop.main.perform {
            MainActor.assumeIsolated {
                guard !planned.isEmpty else { return end() }
                let (title, test) = planned.removeFirst()
                let began = ContinuousClock.now
                test.run()
                executed += test.testRun?.executionCount ?? 0
                failed += test.testRun?.totalFailureCount ?? 0
                let took = (ContinuousClock.now - began).components
                let milliseconds = took.seconds * 1_000 + took.attoseconds / 1_000_000_000_000_000
                let outcome = test.testRun?.hasSucceeded == true ? "passed" : "FAILED"
                progress.note("[\(count - planned.count)/\(count)] \(title) \(outcome) in \(milliseconds) ms")
                next()
            }
        }
    }

    private static func end() {
        say("Executed \(executed) tests, with \(failed) failures")
        exit(failed == 0 ? 0 : 1)
    }

    /// Writes `line` to standard error, which nothing buffers.
    nonisolated static func say(_ line: String) {
        FileHandle.standardError.write(Data((line + "\n").utf8))
    }

    /// Every test case class of this module, by name: the direct subclasses of `XCTestCase` in the application's
    /// own binary - read by name, since a class of the whole process may be no object at all - so a new one runs
    /// without being listed anywhere.
    private static func testCases() -> [XCTestCase.Type] {
        var count: UInt32 = 0
        guard let image = class_getImageName(UIKitTestApplicationDelegate.self),
              let names = objc_copyClassNamesForImage(image, &count)
        else { return [] }
        defer { free(names) }
        return (0..<Int(count)).compactMap { index -> XCTestCase.Type? in
            guard let candidate = objc_lookUpClass(names[index]), class_getSuperclass(candidate) == XCTestCase.self
            else { return nil }
            return candidate as? XCTestCase.Type
        }
        .sorted { NSStringFromClass($0) < NSStringFromClass($1) }
    }

    /// "Case.test" for XCTest's "-[Module.Case test]".
    private static func title(of test: XCTest) -> String {
        let bare = test.name.trimmingCharacters(in: CharacterSet(charactersIn: "-[]"))
        let parts = bare.split(separator: " ")
        let testCase = parts.first.map { $0.split(separator: ".").last.map(String.init) ?? String($0) } ?? bare
        return parts.count == 2 ? "\(testCase).\(parts[1])" : bare
    }
}

/// The application's delegate: its scenes are the runner's.
@MainActor
final class UIKitTestApplicationDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication, configurationForConnecting session: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: session.role)
        configuration.delegateClass = UIKitTestSceneDelegate.self
        return configuration
    }
}

/// The first scene iOS connects is the one the tests' windows stand in; the run begins with it.
@MainActor
final class UIKitTestSceneDelegate: UIResponder, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene, TestScene.scene == nil else { return }
        UIKitTestRunner.begin(in: scene)
    }
}
