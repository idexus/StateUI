// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Android
import CStateUIAndroid
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
@_spi(Host) import StateUIConformance
import XCTest

/// Every test case the runner runs. A case missing here never runs, so
/// test-android.sh refuses a `func test` that no `allTests` lists.
nonisolated(unsafe) let testCases: [XCTestCaseEntry] = [
    testCase(AndroidRendererTests.allTests),
    testCase(AndroidActTests.allTests),
    testCase(AndroidLeaveTests.allTests),
    testCase(AndroidMotionTests.allTests),
    testCase(AndroidAccessibilityTests.allTests),
    testCase(AndroidGestureTests.allTests),
    testCase(AndroidTextualViewTests.allTests),
    testCase(AndroidViewTests.allTests),
    testCase(AndroidButtonViewTests.allTests),
    testCase(AndroidDeclarationExportTests.allTests),
    testCase(AndroidSwitchViewTests.allTests),
    testCase(AndroidCheckBoxViewTests.allTests),
    testCase(AndroidRadioButtonViewTests.allTests),
    testCase(AndroidPickerViewTests.allTests),
    testCase(AndroidDateFieldViewTests.allTests),
    testCase(AndroidShapeViewTests.allTests),
    testCase(AndroidCanvasViewTests.allTests),
    testCase(AndroidBrushTests.allTests),
    testCase(AndroidFrameReportTests.allTests),
    testCase(AndroidWebViewTests.allTests),
    testCase(AndroidSliderViewTests.allTests),
    testCase(AndroidTextFieldViewTests.allTests),
    testCase(AndroidStackViewTests.allTests),
    testCase(AndroidGridViewTests.allTests),
    testCase(AndroidZStackViewTests.allTests),
    testCase(AndroidImageViewTests.allTests),
    testCase(AndroidColorBoxViewTests.allTests),
    testCase(AndroidScrollViewTests.allTests),
    testCase(AndroidInputTests.allTests),
    testCase(AndroidTextViewTests.allTests),
    testCase(AndroidIndicatorViewTests.allTests),
    testCase(AndroidCrossingTests.allTests),
    testCase(AndroidPagesTests.allTests),
    testCase(AndroidMenusTests.allTests),
    testCase(AndroidLayoutMotionTests.allTests),
    testCase(AndroidRegistrationTests.allTests),
    testCase(AndroidConformanceTests.allTests),
    // Last: the application's registrations it makes stay in the host's registry, which nothing after it reads.
    testCase(AndroidInteropTests.allTests),
]

/// Registers the host's natives and the runner's own as the test APK loads this library.
@_cdecl("JNI_OnLoad")
public func JNI_OnLoad(_ machine: UnsafeMutableRawPointer?, _ reserved: UnsafeMutableRawPointer?) -> Int32 {
    let version = StateUIAndroid.load(machine)
    guard version > 0, let env = Java.machine.flatMap(AndroidTestRunner.environment) else { return version }

    return AndroidTestRunner.register(env) ? version : -1
}

/// Runs the test cases on the UI thread, inside the instrumentation's process, one item in each of the thread's
/// messages, and answers the report: `begin` plans the items, `run` runs one, `end` reports them all.
/// Design: docs/design/platforms/android/conformance.md#a-message-an-item
enum AndroidTestRunner {
    static func environment(_ machine: UnsafeMutablePointer<JavaVM?>) -> UnsafeMutablePointer<JNIEnv?>? {
        var raw: UnsafeMutableRawPointer?
        guard machine.pointee!.pointee.GetEnv(machine, &raw, JNI_VERSION_1_6) == JNI_OK else { return nil }
        return raw?.assumingMemoryBound(to: JNIEnv?.self)
    }

    static func register(_ env: UnsafeMutablePointer<JNIEnv?>) -> Bool {
        typealias Env = UnsafeMutablePointer<JNIEnv?>?
        let begin: @convention(c) (Env, jclass?, jobject?, jobject?, jstring?) -> jobjectArray? = {
            env, _, context, window, filter in
            AndroidTestRunner.begin(env: env!, context: context!, window: window!, filter: filter)
        }
        let run: @convention(c) (Env, jclass?, jstring?) -> Void = { _, _, item in
            AndroidTestRunner.run(item: item)
        }
        let end: @convention(c) (Env, jclass?) -> jstring? = { env, _ in
            AndroidTestRunner.end(env: env!)
        }

        let functions = env.pointee!.pointee
        guard let runner = functions.FindClass(env, "stateui/android/test/StateUITestRunner") else { return false }

        let natives: [(String, String, UnsafeMutableRawPointer)] = [
            ("begin", "(Landroid/content/Context;Landroid/app/Activity;Ljava/lang/String;)[Ljava/lang/String;",
             unsafeBitCast(begin, to: UnsafeMutableRawPointer.self)),
            ("run", "(Ljava/lang/String;)V", unsafeBitCast(run, to: UnsafeMutableRawPointer.self)),
            ("end", "()Ljava/lang/String;", unsafeBitCast(end, to: UnsafeMutableRawPointer.self)),
        ]
        let names = natives.map { (strdup($0.0)!, strdup($0.1)!) }
        defer { names.forEach { free($0.0); free($0.1) } }
        var methods = zip(natives, names).map { native, name in
            JNINativeMethod(name: UnsafePointer(name.0), signature: UnsafePointer(name.1), fnPtr: native.2)
        }
        return functions.RegisterNatives(env, runner, &methods, jint(methods.count)) == JNI_OK
    }

    /// The items planned, by name, each with what it runs.
    nonisolated(unsafe) private static var planned: [String: XCTestCase] = [:]

    /// What the runs said, and how many ran and failed.
    nonisolated(unsafe) private static let observer = ReportingObserver()
    nonisolated(unsafe) private static var executed = 0
    nonisolated(unsafe) private static var failed = 0

    /// How many items the run holds, and how many have ended: each says so as it ends (`HostLog.note`).
    nonisolated(unsafe) private static var count = 0
    nonisolated(unsafe) private static var ended = 0
    private static let progress = HostLog(host: "Android Views")

    /// The most cases of a conformance family one item runs: a family longer than that runs in parts, each in a
    /// message of its own, so no message of the UI thread runs long.
    static let casesAnItem = 15

    private static func begin(
        env: UnsafeMutablePointer<JNIEnv?>, context: jobject, window: jobject, filter: jstring?
    ) -> jobjectArray? {
        // The first drain makes this thread MainActor's, as the activity's start does.
        let core = CoreLink()
        _ = core.needsRender
        _ = core.runJobs()

        nonisolated(unsafe) let env = env
        nonisolated(unsafe) let context = context
        nonisolated(unsafe) let window = window
        nonisolated(unsafe) let filter = filter

        let items = MainActor.assumeIsolated { () -> [String] in
            AndroidStandardStreams.redirect()
            Java.env = env
            TestContext.context = JavaObject(Java.jni.NewLocalRef(env, context)!)
            TestContext.window = JavaObject(Java.jni.NewLocalRef(env, window)!)
            XCTestObservationCenter.shared.addTestObserver(observer)
            let items = plan(filter: Java.text(filter))
            count = items.count
            return items
        }

        let stringClass = env.pointee!.pointee.FindClass(env, "java/lang/String")
        let array = env.pointee!.pointee.NewObjectArray(env, jsize(items.count), stringClass, nil)
        for (index, item) in items.enumerated() {
            var units = Array(item.utf16)
            let string = env.pointee!.pointee.NewString(env, &units, jsize(units.count))
            env.pointee!.pointee.SetObjectArrayElement(env, array, jsize(index), string)
            env.pointee!.pointee.DeleteLocalRef(env, string)
        }
        return array
    }

    /// Every test whose "Case.test" name holds one of `filter`'s names, split at commas - every test where it is
    /// empty - a long conformance family in parts, each named "Case.test@part/parts", which a filter may name alone.
    @MainActor
    private static func plan(filter: String) -> [String] {
        let names = filter.split(separator: ",").map { $0.trimmingPrefix(" ") }.filter { !$0.isEmpty }
        let wanted = { (title: String) in names.isEmpty || names.contains { title.contains($0) } }
        var items: [String] = []
        for entry in testCases {
            for (name, test) in entry.allTests {
                let title = "\(entry.testCaseClass).\(name)"
                if entry.testCaseClass == AndroidConformanceTests.self,
                   let family = Families.all.first(where: { "test\($0.name)" == name }),
                   family.cases.count > casesAnItem {
                    let count = (family.cases.count + casesAnItem - 1) / casesAnItem
                    for number in 1...count where wanted("\(title)@\(number)/\(count)") {
                        let item = "\(title)@\(number)/\(count)"
                        planned[item] = AndroidConformanceTests(name: "\(name)@\(number)/\(count)") { testCase in
                            try (testCase as! AndroidConformanceTests).conform(
                                family, part: Conformance.Part(number, of: count))
                        }
                        items.append(item)
                    }
                } else if wanted(title) {
                    planned[title] = entry.testCaseClass.init(name: name, testClosure: test)
                    items.append(title)
                }
            }
        }
        return items
    }

    private static func run(item: jstring?) {
        nonisolated(unsafe) let item = item
        MainActor.assumeIsolated {
            let name = Java.text(item)
            guard let test = planned.removeValue(forKey: name) else { return }
            let began = ContinuousClock.now
            test.run()
            executed += test.testRun?.executionCount ?? 0
            failed += test.testRun?.totalFailureCount ?? 0
            ended += 1
            let took = (ContinuousClock.now - began).components
            let milliseconds = took.seconds * 1_000 + took.attoseconds / 1_000_000_000_000_000
            let outcome = test.testRun?.hasSucceeded == true ? "passed" : "FAILED"
            progress.note("[\(ended)/\(count)] \(name) \(outcome) in \(milliseconds) ms")
        }
    }

    private static func end(env: UnsafeMutablePointer<JNIEnv?>) -> jstring? {
        observer.lines.append("Executed \(executed) tests, with \(failed) failures")
        let report = observer.lines.joined(separator: "\n")
        print(report)
        var units = Array(report.utf16)
        return env.pointee!.pointee.NewString(env, &units, jsize(units.count))
    }
}

/// Writes what each test case did, and every failure where it happened.
private final class ReportingObserver: XCTestObservation {
    var lines: [String] = []

    func testCase(
        _ testCase: XCTestCase, didFailWithDescription description: String, inFile filePath: String?, atLine lineNumber: Int
    ) {
        lines.append("\(filePath ?? "?"):\(lineNumber): error: \(testCase.name) : \(description)")
    }

    func testCaseDidFinish(_ testCase: XCTestCase) {
        let passed = testCase.testRun?.hasSucceeded == true
        lines.append("Test Case '\(testCase.name)' \(passed ? "passed" : "failed")")
    }
}
