// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Android
import StateUIAndroid

/// What the Java web views tell their Swift controls: the native methods of `stateui.webview.StateUIWebViewNatives`,
/// registered as the first view is made, each reaching a control by the number it gave its view - and the scripts
/// waiting for their answers, by ticket.
@MainActor
enum AndroidWebViewNatives {
    private static var controls: [Int64: Weak] = [:]
    private static var next: Int64 = 1
    private static var scripts: [Int64: CheckedContinuation<String?, Never>] = [:]
    private static var nextTicket: Int64 = 1
    private static var registered = false

    private final class Weak {
        weak var control: AndroidWebView?

        init(_ control: AndroidWebView) {
            self.control = control
        }
    }

    /// The next control's number.
    static func reserve() -> Int64 {
        defer { next += 1 }
        return next
    }

    static func hold(_ control: AndroidWebView, as number: Int64) {
        controls[number] = Weak(control)
    }

    static func forget(_ number: Int64) {
        controls[number] = nil
    }

    /// Keeps `answer` until the script under the ticket this answers is answered.
    static func wait(_ answer: CheckedContinuation<String?, Never>) -> Int64 {
        defer { nextTicket += 1 }
        scripts[nextTicket] = answer
        return nextTicket
    }

    private static func control(_ number: jlong) -> AndroidWebView? {
        controls[number]?.control
    }

    /// Registers the native methods, once: Java's environment stands only once the activity started the host.
    static func register() {
        guard !registered else { return }
        registered = true

        typealias Environment = UnsafeMutablePointer<JNIEnv?>?
        let navigating: @convention(c) (Environment, jclass?, jlong, jint, jstring?) -> Void = { _, _, number, cause, address in
            nonisolated(unsafe) let address = address
            MainActor.assumeIsolated {
                AndroidWebViewNatives.control(number)?.navigating(cause: cause, to: Java.text(address))
            }
        }
        let navigated: @convention(c) (Environment, jclass?, jlong, jint, jint, jstring?) -> Void = {
            _, _, number, result, cause, address in
            nonisolated(unsafe) let address = address
            MainActor.assumeIsolated {
                AndroidWebViewNatives.control(number)?.navigated(result: result, cause: cause, to: Java.text(address))
            }
        }
        let history: @convention(c) (Environment, jclass?, jlong, jboolean, jboolean) -> Void = { _, _, number, back, forward in
            MainActor.assumeIsolated {
                AndroidWebViewNatives.control(number)?.historyChanged(back: back != 0, forward: forward != 0)
            }
        }
        let gone: @convention(c) (Environment, jclass?, jlong) -> Void = { _, _, number in
            MainActor.assumeIsolated { AndroidWebViewNatives.control(number)?.processGone() }
        }
        let answered: @convention(c) (Environment, jclass?, jlong, jstring?) -> Void = { _, _, ticket, text in
            nonisolated(unsafe) let text = text
            MainActor.assumeIsolated {
                AndroidWebViewNatives.scripts.removeValue(forKey: ticket)?.resume(returning: text.map { Java.text($0) })
            }
        }

        let natives: [(String, String, UnsafeMutableRawPointer)] = [
            ("navigating", "(JILjava/lang/String;)V", unsafeBitCast(navigating, to: UnsafeMutableRawPointer.self)),
            ("navigated", "(JIILjava/lang/String;)V", unsafeBitCast(navigated, to: UnsafeMutableRawPointer.self)),
            ("history", "(JZZ)V", unsafeBitCast(history, to: UnsafeMutableRawPointer.self)),
            ("processGone", "(J)V", unsafeBitCast(gone, to: UnsafeMutableRawPointer.self)),
            ("answered", "(JLjava/lang/String;)V", unsafeBitCast(answered, to: UnsafeMutableRawPointer.self)),
        ]
        let names = natives.map { strdup($0.0)! }
        let signatures = natives.map { strdup($0.1)! }
        defer { (names + signatures).forEach { free($0) } }
        var methods = natives.indices.map { index in
            JNINativeMethod(
                name: UnsafePointer(names[index]), signature: UnsafePointer(signatures[index]), fnPtr: natives[index].2)
        }
        let owner = Java.findClass("stateui/webview/StateUIWebViewNatives")
        _ = Java.jni.RegisterNatives(Java.env, owner, &methods, jint(methods.count))
    }
}
