// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Android
import CStateUIAndroid
@_spi(Host) import StateUI
@testable import StateUIAndroid
import XCTest

/// Every test case the runner runs. A case missing here never runs, so
/// test-android.sh refuses a `func test` that no `allTests` lists.
nonisolated(unsafe) let testCases: [XCTestCaseEntry] = [
    testCase(AndroidRendererTests.allTests),
    testCase(AndroidLeaveTests.allTests),
    testCase(AndroidMotionTests.allTests),
    testCase(AndroidTextViewTests.allTests),
    testCase(AndroidViewTests.allTests),
    testCase(AndroidSwitchViewTests.allTests),
    testCase(AndroidSliderViewTests.allTests),
    testCase(AndroidTextFieldViewTests.allTests),
    testCase(AndroidStackViewTests.allTests),
    testCase(AndroidGridViewTests.allTests),
    testCase(AndroidAbsoluteLayoutViewTests.allTests),
    testCase(AndroidBorderViewTests.allTests),
    testCase(AndroidImageViewTests.allTests),
    testCase(AndroidColorBoxViewTests.allTests),
    testCase(AndroidScrollViewTests.allTests),
    testCase(AndroidLayoutMotionTests.allTests),
    testCase(AndroidRegistrationTests.allTests),
]

/// Registers the host's natives and the runner's own as the test APK loads this library.
@_cdecl("JNI_OnLoad")
public func JNI_OnLoad(_ machine: UnsafeMutableRawPointer?, _ reserved: UnsafeMutableRawPointer?) -> Int32 {
    let version = StateUIAndroid.load(machine)
    guard version > 0, let env = Java.machine.flatMap(AndroidTestRunner.environment) else { return version }

    return AndroidTestRunner.register(env) ? version : -1
}

/// Runs every test case on the UI thread, inside the instrumentation's process, and answers the report.
enum AndroidTestRunner {
    static func environment(_ machine: UnsafeMutablePointer<JavaVM?>) -> UnsafeMutablePointer<JNIEnv?>? {
        var raw: UnsafeMutableRawPointer?
        guard machine.pointee!.pointee.GetEnv(machine, &raw, JNI_VERSION_1_6) == JNI_OK else { return nil }
        return raw?.assumingMemoryBound(to: JNIEnv?.self)
    }

    static func register(_ env: UnsafeMutablePointer<JNIEnv?>) -> Bool {
        let run: @convention(c) (UnsafeMutablePointer<JNIEnv?>?, jclass?, jobject?) -> jstring? = { env, _, context in
            AndroidTestRunner.run(env: env!, context: context!)
        }

        let functions = env.pointee!.pointee
        guard let runner = functions.FindClass(env, "stateui/android/test/StateUITestRunner") else { return false }

        let name = strdup("run")!
        let signature = strdup("(Landroid/content/Context;)Ljava/lang/String;")!
        defer {
            free(name)
            free(signature)
        }
        var method = JNINativeMethod(
            name: UnsafePointer(name), signature: UnsafePointer(signature),
            fnPtr: unsafeBitCast(run, to: UnsafeMutableRawPointer.self))
        return functions.RegisterNatives(env, runner, &method, 1) == JNI_OK
    }

    private static func run(env: UnsafeMutablePointer<JNIEnv?>, context: jobject) -> jstring? {
        // The first drain makes this thread MainActor's, as the activity's start does.
        let core = CoreLink()
        _ = core.needsRender
        _ = core.runJobs()

        nonisolated(unsafe) let env = env
        nonisolated(unsafe) let context = context

        let report = MainActor.assumeIsolated {
            AndroidStandardStreams.redirect()
            Java.env = env
            TestContext.context = JavaObject(Java.jni.NewLocalRef(env, context)!)
            return runSuite()
        }

        print(report)
        var units = Array(report.utf16)
        return env.pointee!.pointee.NewString(env, &units, jsize(units.count))
    }

    private static func runSuite() -> String {
        let suite = XCTestSuite(name: "StateUIAndroidTests")
        for entry in testCases {
            let cases = XCTestSuite(name: "\(entry.testCaseClass)")
            for (name, test) in entry.allTests {
                cases.addTest(entry.testCaseClass.init(name: name, testClosure: test))
            }
            suite.addTest(cases)
        }

        let observer = ReportingObserver()
        XCTestObservationCenter.shared.addTestObserver(observer)
        suite.run()

        let run = suite.testRun!
        observer.lines.append(
            "Executed \(run.executionCount) tests, with \(run.totalFailureCount) failures")
        return observer.lines.joined(separator: "\n")
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
