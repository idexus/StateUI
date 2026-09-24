// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import Android
import CStateUIAndroid

/// Runs a StateUI application as native Android views in the application's own process.
///
/// An application's Android head is a library Android loads; its `JNI_OnLoad`
/// names the application and hands the virtual machine to the host:
///
///     import HelloWorldUI
///     import StateUIAndroid
///
///     @_cdecl("JNI_OnLoad")
///     public func JNI_OnLoad(_ machine: UnsafeMutableRawPointer?, _ reserved: UnsafeMutableRawPointer?) -> Int32 {
///         stateui_app_register()
///         return StateUIAndroid.load(machine)
///     }
///
/// The head's manifest declares `stateui.android.StateUIActivity`, which starts
/// the host. A control this host does not present yet shows its name in red
/// where it belongs.
public enum StateUIAndroid {
    /// Registers the host's native methods with the Java layer and answers the JNI version the host needs.
    ///
    /// - Parameter machine: the `JavaVM` pointer `JNI_OnLoad` received.
    /// - Returns: the JNI version `JNI_OnLoad` answers.
    public static func load(_ machine: UnsafeMutableRawPointer?) -> Int32 {
        guard let machine = machine?.assumingMemoryBound(to: JavaVM?.self) else { return JNI_ERR }

        Java.machine = machine
        var raw: UnsafeMutableRawPointer?
        guard machine.pointee!.pointee.GetEnv(machine, &raw, JNI_VERSION_1_6) == JNI_OK, let raw else {
            return JNI_ERR
        }

        let env = raw.assumingMemoryBound(to: JNIEnv?.self)
        return JavaNatives.register(env) ? JNI_VERSION_1_6 : JNI_ERR
    }
}

/// The native methods `stateui.android.StateUIHost` declares, each registered by name.
/// Design: docs/design/platforms/android/jni.md#the-natives
enum JavaNatives {
    typealias Environment = UnsafeMutablePointer<JNIEnv?>?

    /// Registers every native method with the class declaring them.
    static func register(_ env: UnsafeMutablePointer<JNIEnv?>) -> Bool {
        let start: @convention(c) (Environment, jclass?, jobject?, jobject?, jfloat) -> Void = {
            env, _, activity, root, density in
            JavaNatives.start(env: env!, activity: activity!, root: root!, density: Double(density))
        }
        let phase: @convention(c) (Environment, jclass?, jint) -> Void = { _, _, phase in
            MainActor.assumeIsolated {
                AndroidRenderer.shared?.setPhase(ApplicationPhase(rawValue: phase) ?? .active)
            }
        }
        let configured: @convention(c) (Environment, jclass?) -> Void = { _, _ in
            MainActor.assumeIsolated { AndroidRenderer.shared?.configured() }
        }
        let back: @convention(c) (Environment, jclass?) -> jboolean = { _, _ in
            MainActor.assumeIsolated { AndroidRenderer.shared?.goBack() == true ? 1 : 0 }
        }
        let frame: @convention(c) (Environment, jclass?, jlong) -> Void = { _, _, time in
            MainActor.assumeIsolated {
                AndroidFrameClock.current?.frame(Double(time) / 1_000_000)
            }
        }
        let clicked: @convention(c) (Environment, jclass?, jlong) -> Void = { _, _, number in
            MainActor.assumeIsolated {
                AndroidView.find(number)?.clicked()
            }
        }
        let menuChose: @convention(c) (Environment, jclass?, jlong, jint) -> Void = { _, _, number, item in
            MainActor.assumeIsolated {
                AndroidView.find(number)?.menuChose(Int(item))
            }
        }
        let menuOpening: @convention(c) (Environment, jclass?, jlong, jobject?) -> Void = { _, _, number, menu in
            nonisolated(unsafe) let menu = menu
            MainActor.assumeIsolated {
                guard let menu else { return }
                AndroidView.find(number)?.menuOpening(menu)
            }
        }
        let tabSelected: @convention(c) (Environment, jclass?, jlong, jint) -> Void = { _, _, number, tab in
            MainActor.assumeIsolated {
                (AndroidView.find(number) as? AndroidTabsView)?.onChosen?(Int(tab))
            }
        }
        let toggled: @convention(c) (Environment, jclass?, jlong, jboolean) -> Void = { _, _, number, on in
            MainActor.assumeIsolated {
                (AndroidView.find(number) as? AndroidToggleView)?.onToggled?(on != 0)
            }
        }
        let moved: @convention(c) (Environment, jclass?, jlong, jint) -> Void = { _, _, number, progress in
            MainActor.assumeIsolated {
                guard let slider = AndroidView.find(number) as? AndroidSliderView else { return }
                slider.onValueChanged?(slider.value(at: progress))
            }
        }
        let dragStarted: @convention(c) (Environment, jclass?, jlong) -> Void = { _, _, number in
            MainActor.assumeIsolated {
                (AndroidView.find(number) as? AndroidSliderView)?.onDragStarted?()
            }
        }
        let dragCompleted: @convention(c) (Environment, jclass?, jlong) -> Void = { _, _, number in
            MainActor.assumeIsolated {
                (AndroidView.find(number) as? AndroidSliderView)?.onDragCompleted?()
            }
        }
        let textChanged: @convention(c) (Environment, jclass?, jlong, jstring?) -> Void = { _, _, number, text in
            nonisolated(unsafe) let text = text
            MainActor.assumeIsolated {
                (AndroidView.find(number) as? AndroidTextFieldView)?.typed(Java.text(text))
            }
        }
        let submitted: @convention(c) (Environment, jclass?, jlong) -> Void = { _, _, number in
            MainActor.assumeIsolated {
                (AndroidView.find(number) as? AndroidTextFieldView)?.onSubmitted?()
            }
        }
        let scrolled: @convention(c) (Environment, jclass?, jlong) -> Void = { _, _, number in
            MainActor.assumeIsolated {
                (AndroidView.find(number) as? AndroidScrollView)?.scrolled()
            }
        }
        let held: @convention(c) (Environment, jclass?, jlong, jboolean) -> Void = { _, _, number, holding in
            MainActor.assumeIsolated {
                AndroidView.find(number)?.held(holding != 0)
            }
        }
        let opened: @convention(c) (Environment, jclass?, jlong) -> Void = { _, _, number in
            MainActor.assumeIsolated { AndroidView.find(number)?.opened() }
        }
        let closed: @convention(c) (Environment, jclass?, jlong) -> Void = { _, _, number in
            MainActor.assumeIsolated { AndroidView.find(number)?.closed() }
        }
        let fieldChose: @convention(c) (Environment, jclass?, jlong, jint, jint, jint) -> Void = {
            _, _, number, first, second, third in
            MainActor.assumeIsolated {
                (AndroidView.find(number) as? AndroidDateFieldView)?.chose(Int(first), Int(second), Int(third))
            }
        }
        let chose: @convention(c) (Environment, jclass?, jlong, jint) -> Void = { _, _, number, index in
            MainActor.assumeIsolated {
                (AndroidView.find(number) as? AndroidPickerView)?.onChosen?(Int(index))
            }
        }
        let canvasTouched: @convention(c) (Environment, jclass?, jlong, jint, jfloat, jfloat) -> Void = {
            _, _, number, phase, x, y in
            MainActor.assumeIsolated {
                (AndroidView.find(number) as? AndroidCanvasView)?.touched(phase: phase, at: Point(Double(x), Double(y)))
            }
        }
        let answered: @convention(c) (Environment, jclass?, jlong, jboolean, jstring?) -> Void = {
            _, _, ticket, accepted, words in
            nonisolated(unsafe) let words = words
            MainActor.assumeIsolated {
                AndroidRenderer.shared?.answered(ticket: ticket, accepted: accepted != 0, words: words.map { Java.text($0) })
            }
        }
        let webNavigating: @convention(c) (Environment, jclass?, jlong, jint, jstring?) -> Void = {
            _, _, number, cause, address in
            nonisolated(unsafe) let address = address
            MainActor.assumeIsolated {
                (AndroidView.find(number) as? AndroidWebView)?.navigating(cause: cause, to: Java.text(address))
            }
        }
        let webNavigated: @convention(c) (Environment, jclass?, jlong, jint, jint, jstring?) -> Void = {
            _, _, number, result, cause, address in
            nonisolated(unsafe) let address = address
            MainActor.assumeIsolated {
                (AndroidView.find(number) as? AndroidWebView)?.navigated(result: result, cause: cause, to: Java.text(address))
            }
        }
        let webHistory: @convention(c) (Environment, jclass?, jlong, jboolean, jboolean) -> Void = {
            _, _, number, back, forward in
            MainActor.assumeIsolated {
                (AndroidView.find(number) as? AndroidWebView)?.history(back: back != 0, forward: forward != 0)
            }
        }
        let webProcessGone: @convention(c) (Environment, jclass?, jlong) -> Void = { _, _, number in
            MainActor.assumeIsolated {
                (AndroidView.find(number) as? AndroidWebView)?.onProcessGone?()
            }
        }
        let laidOut: @convention(c) (Environment, jclass?) -> Void = { _, _ in
            MainActor.assumeIsolated {
                AndroidRenderer.shared?.laidOut()
            }
        }
        let measure: @convention(c) (Environment, jclass?, jlong, jint, jint) -> jlong = {
            _, _, number, widthSpec, heightSpec in
            MainActor.assumeIsolated {
                guard let layout = AndroidView.find(number) as? AndroidLayoutView else { return 0 }

                let size = layout.measure(widthSpec: widthSpec, heightSpec: heightSpec)
                return Int64(size.width) << 32 | Int64(UInt32(bitPattern: size.height))
            }
        }
        let arrange: @convention(c) (Environment, jclass?, jlong, jint, jint) -> Void = {
            _, _, number, width, height in
            MainActor.assumeIsolated {
                (AndroidView.find(number) as? AndroidLayoutView)?.arrange(width: width, height: height)
            }
        }

        let natives: [(String, String, UnsafeMutableRawPointer)] = [
            ("start", "(Landroid/app/Activity;Landroid/widget/FrameLayout;F)V", unsafeBitCast(start, to: UnsafeMutableRawPointer.self)),
            ("phase", "(I)V", unsafeBitCast(phase, to: UnsafeMutableRawPointer.self)),
            ("configured", "()V", unsafeBitCast(configured, to: UnsafeMutableRawPointer.self)),
            ("back", "()Z", unsafeBitCast(back, to: UnsafeMutableRawPointer.self)),
            ("frame", "(J)V", unsafeBitCast(frame, to: UnsafeMutableRawPointer.self)),
            ("clicked", "(J)V", unsafeBitCast(clicked, to: UnsafeMutableRawPointer.self)),
            ("menuChose", "(JI)V", unsafeBitCast(menuChose, to: UnsafeMutableRawPointer.self)),
            ("menuOpening", "(JLandroid/view/Menu;)V", unsafeBitCast(menuOpening, to: UnsafeMutableRawPointer.self)),
            ("tabSelected", "(JI)V", unsafeBitCast(tabSelected, to: UnsafeMutableRawPointer.self)),
            ("toggled", "(JZ)V", unsafeBitCast(toggled, to: UnsafeMutableRawPointer.self)),
            ("moved", "(JI)V", unsafeBitCast(moved, to: UnsafeMutableRawPointer.self)),
            ("dragStarted", "(J)V", unsafeBitCast(dragStarted, to: UnsafeMutableRawPointer.self)),
            ("dragCompleted", "(J)V", unsafeBitCast(dragCompleted, to: UnsafeMutableRawPointer.self)),
            ("textChanged", "(JLjava/lang/String;)V", unsafeBitCast(textChanged, to: UnsafeMutableRawPointer.self)),
            ("submitted", "(J)V", unsafeBitCast(submitted, to: UnsafeMutableRawPointer.self)),
            ("scrolled", "(J)V", unsafeBitCast(scrolled, to: UnsafeMutableRawPointer.self)),
            ("held", "(JZ)V", unsafeBitCast(held, to: UnsafeMutableRawPointer.self)),
            ("opened", "(J)V", unsafeBitCast(opened, to: UnsafeMutableRawPointer.self)),
            ("closed", "(J)V", unsafeBitCast(closed, to: UnsafeMutableRawPointer.self)),
            ("fieldChose", "(JIII)V", unsafeBitCast(fieldChose, to: UnsafeMutableRawPointer.self)),
            ("chose", "(JI)V", unsafeBitCast(chose, to: UnsafeMutableRawPointer.self)),
            ("canvasTouched", "(JIFF)V", unsafeBitCast(canvasTouched, to: UnsafeMutableRawPointer.self)),
            ("answered", "(JZLjava/lang/String;)V", unsafeBitCast(answered, to: UnsafeMutableRawPointer.self)),
            ("webNavigating", "(JILjava/lang/String;)V", unsafeBitCast(webNavigating, to: UnsafeMutableRawPointer.self)),
            ("webNavigated", "(JIILjava/lang/String;)V", unsafeBitCast(webNavigated, to: UnsafeMutableRawPointer.self)),
            ("webHistory", "(JZZ)V", unsafeBitCast(webHistory, to: UnsafeMutableRawPointer.self)),
            ("webProcessGone", "(J)V", unsafeBitCast(webProcessGone, to: UnsafeMutableRawPointer.self)),
            ("laidOut", "()V", unsafeBitCast(laidOut, to: UnsafeMutableRawPointer.self)),
            ("measure", "(JII)J", unsafeBitCast(measure, to: UnsafeMutableRawPointer.self)),
            ("arrange", "(JII)V", unsafeBitCast(arrange, to: UnsafeMutableRawPointer.self)),
        ]

        let functions = env.pointee!.pointee
        guard let host = functions.FindClass(env, "stateui/android/StateUIHost") else {
            functions.ExceptionClear(env)
            AndroidLog.error("stateui.android.StateUIHost is missing from the application")
            return false
        }

        let names = natives.map { strdup($0.0)! }
        let signatures = natives.map { strdup($0.1)! }
        defer { (names + signatures).forEach { free($0) } }

        var methods = natives.indices.map { index in
            JNINativeMethod(
                name: UnsafePointer(names[index]), signature: UnsafePointer(signatures[index]),
                fnPtr: natives[index].2)
        }
        return functions.RegisterNatives(env, host, &methods, jint(methods.count)) == JNI_OK
    }

    /// The activity starts the host: the first drain makes this thread MainActor's, then the first render.
    /// Design: docs/design/platforms/android/runtime.md#starting
    private static func start(env: UnsafeMutablePointer<JNIEnv?>, activity: jobject, root: jobject, density: Double) {
        let core = CoreLink()
        _ = core.needsRender
        _ = core.runJobs()

        nonisolated(unsafe) let env = env
        nonisolated(unsafe) let activity = activity
        nonisolated(unsafe) let root = root

        MainActor.assumeIsolated {
            AndroidStandardStreams.redirect()
            Java.env = env
            if Java.classLoader == nil, let loader = Java.callObject(activity, JavaAPI.getClassLoader) {
                Java.classLoader = JavaObject(loader)
            }
            AndroidRenderer.start(
                context: JavaObject(Java.jni.NewLocalRef(env, activity)!),
                root: JavaObject(Java.jni.NewLocalRef(env, root)!),
                density: density)
        }
    }
}
