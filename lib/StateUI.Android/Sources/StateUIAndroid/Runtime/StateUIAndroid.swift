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
        let frame: @convention(c) (Environment, jclass?, jlong) -> Void = { _, _, time in
            MainActor.assumeIsolated {
                AndroidFrameClock.current?.frame(Double(time) / 1_000_000)
            }
        }
        let clicked: @convention(c) (Environment, jclass?, jlong) -> Void = { _, _, number in
            MainActor.assumeIsolated {
                (AndroidView.find(number) as? AndroidButtonView)?.onClicked?()
            }
        }
        let toggled: @convention(c) (Environment, jclass?, jlong, jboolean) -> Void = { _, _, number, on in
            MainActor.assumeIsolated {
                (AndroidView.find(number) as? AndroidSwitchView)?.onToggled?(on != 0)
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
            ("frame", "(J)V", unsafeBitCast(frame, to: UnsafeMutableRawPointer.self)),
            ("clicked", "(J)V", unsafeBitCast(clicked, to: UnsafeMutableRawPointer.self)),
            ("toggled", "(JZ)V", unsafeBitCast(toggled, to: UnsafeMutableRawPointer.self)),
            ("moved", "(JI)V", unsafeBitCast(moved, to: UnsafeMutableRawPointer.self)),
            ("dragStarted", "(J)V", unsafeBitCast(dragStarted, to: UnsafeMutableRawPointer.self)),
            ("dragCompleted", "(J)V", unsafeBitCast(dragCompleted, to: UnsafeMutableRawPointer.self)),
            ("textChanged", "(JLjava/lang/String;)V", unsafeBitCast(textChanged, to: UnsafeMutableRawPointer.self)),
            ("submitted", "(J)V", unsafeBitCast(submitted, to: UnsafeMutableRawPointer.self)),
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
            AndroidRenderer.start(
                context: JavaObject(Java.jni.NewLocalRef(env, activity)!),
                root: JavaObject(Java.jni.NewLocalRef(env, root)!),
                density: density)
        }
    }
}
