// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
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
///         registerApplication()
///         return StateUIAndroid.load(machine)
///     }
///
/// The head's manifest declares `stateui.android.StateUIActivity`, which starts
/// the host. A control this host does not present yet shows its name in red
/// where it belongs.
public enum StateUIAndroid {
    /// The activity the host runs in, which a view of the application's own control is made with; read while the
    /// host runs.
    @MainActor public static var context: jobject { AndroidRenderer.context }

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
        let insets: @convention(c) (Environment, jclass?, jint, jint, jint, jint, jint) -> Void = {
            _, _, left, top, right, bottom, keyboard in
            MainActor.assumeIsolated {
                AndroidRenderer.shared?.insetsChanged(left: left, top: top, right: right, bottom: bottom, keyboard: keyboard)
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
        let keyPressed: @convention(c) (Environment, jclass?, jint, jint, jint) -> jboolean = { _, _, code, character, meta in
            MainActor.assumeIsolated {
                AndroidRenderer.shared?.pressed(code: code, character: character, meta: meta) == true ? 1 : 0
            }
        }
        let keyTaken: @convention(c) (Environment, jclass?, jboolean, jint, jint, jint) -> jboolean = {
            _, _, down, code, character, meta in
            MainActor.assumeIsolated {
                AndroidRenderer.shared?.taken(down: down != 0, code: code, character: character, meta: meta) == true
                    ? 1 : 0
            }
        }
        let longClicked: @convention(c) (Environment, jclass?, jlong) -> jboolean = { _, _, number in
            MainActor.assumeIsolated { AndroidView.find(number)?.longClicked() == true ? 1 : 0 }
        }
        let accessibilityActed: @convention(c) (Environment, jclass?, jlong, jstring?) -> jboolean = {
            _, _, number, action in
            nonisolated(unsafe) let action = action
            return MainActor.assumeIsolated {
                guard let heard = AndroidView.find(number)?.readerHeard else { return 0 }
                return heard(.accessibilityAction(Java.text(action))) ? 1 : 0
            }
        }
        let accessibilityStepped: @convention(c) (Environment, jclass?, jlong, jboolean) -> jboolean = { _, _, number, up in
            MainActor.assumeIsolated {
                guard let heard = AndroidView.find(number)?.readerHeard else { return 0 }
                return heard(.accessibilityAdjustment(up != 0 ? .increment : .decrement)) ? 1 : 0
            }
        }
        let menuChose: @convention(c) (Environment, jclass?, jlong, jint) -> Void = { _, _, number, item in
            MainActor.assumeIsolated {
                AndroidView.find(number)?.menuChose(Int(item))
            }
        }
        let gestured: @convention(c) (Environment, jclass?, jlong, jint, jint, jfloat, jfloat, jfloat) -> Void = {
            _, _, number, kind, phase, x, y, z in
            MainActor.assumeIsolated {
                AndroidView.find(number)?.heard(kind: kind, phase: phase, x: Double(x), y: Double(y), z: Double(z))
            }
        }
        let pressed: @convention(c) (Environment, jclass?, jlong, jint, jfloat, jfloat) -> jboolean = {
            _, _, number, phase, x, y in
            MainActor.assumeIsolated {
                let dragging = AndroidView.find(number)?.heardPress(phase: phase, at: Point(x: Double(x), y: Double(y)))
                return dragging == true ? 1 : 0
            }
        }
        let finger: @convention(c) (
            Environment, jclass?, jlong, jint, jint, jfloat, jfloat, jfloat, jfloat, jfloat, jfloat
        ) -> jboolean = { _, _, number, phase, finger, x, y, inViewX, inViewY, speedX, speedY in
            MainActor.assumeIsolated {
                let taken = AndroidView.find(number)?.heardFinger(
                    phase: phase, finger: Int(finger), at: Point(x: Double(x), y: Double(y)),
                    inView: Point(x: Double(inViewX), y: Double(inViewY)),
                    speed: Point(x: Double(speedX), y: Double(speedY)))
                return taken == true ? 1 : 0
            }
        }
        let fingers: @convention(c) (Environment, jclass?, jlong, jint, jfloat, jfloat, jfloat, jfloat) -> Void = {
            _, _, number, phase, firstX, firstY, secondX, secondY in
            MainActor.assumeIsolated {
                AndroidView.find(number)?.heardFingers(
                    phase: phase, first: Point(x: Double(firstX), y: Double(firstY)),
                    second: Point(x: Double(secondX), y: Double(secondY)))
            }
        }
        let notched: @convention(c) (Environment, jclass?, jlong, jfloat, jfloat) -> jboolean = { _, _, number, x, y in
            MainActor.assumeIsolated {
                AndroidView.find(number)?.heardNotches(Point(x: Double(x), y: Double(y))) == true ? 1 : 0
            }
        }
        let focusChanged: @convention(c) (Environment, jclass?, jlong, jboolean) -> Void = { _, _, number, focused in
            MainActor.assumeIsolated {
                AndroidView.find(number)?.onFocusChanged?(focused != 0)
            }
        }
        let destroying: @convention(c) (Environment, jclass?) -> Void = { _, _ in
            MainActor.assumeIsolated { AndroidRenderer.shared?.destroying() }
        }
        let environmentChanged: @convention(c) (Environment, jclass?) -> Void = { _, _ in
            MainActor.assumeIsolated { AndroidRenderer.shared?.environmentChanged() }
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
                AndroidView.find(number)?.toggled(on != 0)
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
                (AndroidView.find(number) as? AndroidSliderView)?.onPressed?()
            }
        }
        let dragCompleted: @convention(c) (Environment, jclass?, jlong) -> Void = { _, _, number in
            MainActor.assumeIsolated {
                (AndroidView.find(number) as? AndroidSliderView)?.onReleased?()
            }
        }
        let heldWords: @convention(c) (Environment, jclass?, jstring?, jint, jboolean) -> jstring? = {
            _, _, text, bound, composing in
            nonisolated(unsafe) let text = text
            nonisolated(unsafe) var held: jstring?
            MainActor.assumeIsolated {
                held = InputWords.held(Java.text(text), in: nil, toBound: Int(bound), composing: composing != 0)
                    .flatMap(Java.string)
            }
            return held
        }
        let textChanged: @convention(c) (Environment, jclass?, jlong, jstring?, jboolean) -> Void = {
            _, _, number, text, composing in
            nonisolated(unsafe) let text = text
            MainActor.assumeIsolated {
                (AndroidView.find(number) as? AndroidTextFieldView)?.typed(Java.text(text), composing: composing != 0)
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
        let refreshPulled: @convention(c) (Environment, jclass?, jlong) -> jboolean = { _, _, number in
            MainActor.assumeIsolated {
                (AndroidView.find(number) as? any AndroidRefreshing)?.onRefreshPulled?() == true ? 1 : 0
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
        let actionChosen: @convention(c) (Environment, jclass?, jlong, jint) -> Void = { _, _, ticket, place in
            MainActor.assumeIsolated { AndroidRenderer.shared?.actionChosen(ticket: ticket, place: Int(place)) }
        }
        let filesChosen: @convention(c) (Environment, jclass?, jlong, jobjectArray?, jobjectArray?, jstring?) -> Void = {
            _, _, ticket, addresses, names, failure in
            nonisolated(unsafe) let (addresses, names, failure) = (addresses, names, failure)
            MainActor.assumeIsolated {
                AndroidRenderer.shared?.filesChosen(
                    ticket: ticket, addresses: Java.texts(addresses), names: Java.texts(names),
                    failure: failure.map { Java.text($0) })
            }
        }
        let fileRead: @convention(c) (Environment, jclass?, jlong, jbyteArray?, jstring?) -> Void = {
            _, _, ticket, bytes, failure in
            nonisolated(unsafe) let (bytes, failure) = (bytes, failure)
            MainActor.assumeIsolated {
                AndroidRenderer.shared?.fileRead(
                    ticket: ticket, bytes: Java.bytesOf(bytes), failure: failure.map { Java.text($0) })
            }
        }
        let requestAnswered: @convention(c) (Environment, jclass?, jlong, jint, jobjectArray?, jbyteArray?, jstring?) -> Void = {
            _, _, ticket, status, headers, body, failure in
            nonisolated(unsafe) let (headers, body, failure) = (headers, body, failure)
            MainActor.assumeIsolated {
                AndroidRenderer.shared?.requestAnswered(
                    ticket: ticket, status: Int(status), headers: Java.texts(headers), body: Java.bytesOf(body),
                    failure: failure.map { Java.text($0) })
            }
        }
        let dragHeard: @convention(c) (Environment, jclass?, jlong, jint, jstring?) -> Void = { _, _, number, kind, words in
            nonisolated(unsafe) let words = words
            MainActor.assumeIsolated { AndroidView.find(number)?.heardDrag(kind: kind, words: words.map { Java.text($0) }) }
        }
        let filesDragged: @convention(c) (Environment, jclass?, jlong, jobjectArray?, jobjectArray?) -> Void = {
            _, _, number, addresses, names in
            nonisolated(unsafe) let (addresses, names) = (addresses, names)
            MainActor.assumeIsolated {
                AndroidView.find(number)?.heardDroppedFiles(addresses: Java.texts(addresses), names: Java.texts(names))
            }
        }
        let launched: @convention(c) (Environment, jclass?, jlong, jboolean) -> Void = { _, _, ticket, taken in
            MainActor.assumeIsolated { AndroidRenderer.shared?.launched(ticket: ticket, taken: taken != 0) }
        }
        let webNavigating: @convention(c) (Environment, jclass?, jlong, jstring?) -> Void = {
            _, _, number, address in
            nonisolated(unsafe) let address = address
            MainActor.assumeIsolated {
                (AndroidView.find(number) as? AndroidWebView)?.navigating(to: Java.text(address))
            }
        }
        let webNavigated: @convention(c) (Environment, jclass?, jlong, jint, jstring?) -> Void = {
            _, _, number, result, address in
            nonisolated(unsafe) let address = address
            MainActor.assumeIsolated {
                (AndroidView.find(number) as? AndroidWebView)?.navigated(result: result, to: Java.text(address))
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
        let itemCell: @convention(c) (Environment, jclass?, jlong, jint) -> jobject? = { _, _, number, kind in
            nonisolated(unsafe) var made: jobject?
            MainActor.assumeIsolated {
                guard let list = AndroidView.find(number) as? AndroidItemsView else { return }
                made = Java.jni.NewLocalRef(Java.env, list.makeCell(item: AndroidItemKind(rawValue: kind) == .item).reference)
            }
            return made
        }
        let itemHeld: @convention(c) (Environment, jclass?, jlong, jlong, jstring?) -> Void = {
            _, _, number, cell, identity in
            nonisolated(unsafe) let identity = identity
            MainActor.assumeIsolated {
                guard let list = AndroidView.find(number) as? AndroidItemsView,
                      let cell = AndroidView.find(cell) as? AndroidItemCell else { return }
                list.held(Java.text(identity), in: cell)
            }
        }
        let itemShown: @convention(c) (Environment, jclass?, jlong, jlong, jstring?) -> Void = {
            _, _, number, cell, identity in
            nonisolated(unsafe) let identity = identity
            MainActor.assumeIsolated {
                guard let list = AndroidView.find(number) as? AndroidItemsView,
                      let cell = AndroidView.find(cell) as? AndroidItemCell else { return }
                list.shown(Java.text(identity), in: cell)
            }
        }
        let itemLetGo: @convention(c) (Environment, jclass?, jlong, jlong) -> Void = { _, _, number, cell in
            MainActor.assumeIsolated {
                guard let list = AndroidView.find(number) as? AndroidItemsView,
                      let cell = AndroidView.find(cell) as? AndroidItemCell else { return }
                list.letGo(cell)
            }
        }
        let itemsShowing: @convention(c) (Environment, jclass?, jlong, jobjectArray?) -> Void = {
            _, _, number, identities in
            nonisolated(unsafe) let identities = identities
            MainActor.assumeIsolated {
                (AndroidView.find(number) as? AndroidItemsView)?.showing(Java.texts(identities))
            }
        }
        let itemsDistance: @convention(c) (Environment, jclass?, jlong, jint, jint, jint, jint, jint) -> jint = {
            _, _, number, anchor, start, end, boxStart, boxEnd in
            MainActor.assumeIsolated {
                (AndroidView.find(number) as? AndroidItemsView)?.distance(
                    anchor: anchor, start: start, end: end, boxStart: boxStart, boxEnd: boxEnd) ?? 0
            }
        }
        let laidOut: @convention(c) (Environment, jclass?) -> Void = { _, _ in
            MainActor.assumeIsolated {
                AndroidRenderer.shared?.runtime.frames.laidOut()
            }
        }
        let reportLaidOut: @convention(c) (Environment, jclass?) -> jboolean = { _, _ in
            MainActor.assumeIsolated { AndroidRenderer.shared?.runtime.frames.reportLaidOut() == true ? 1 : 0 }
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
                (AndroidView.find(number) as? AndroidLayoutView)?.laidOut(width: width, height: height)
            }
        }

        let natives: [(String, String, UnsafeMutableRawPointer)] = [
            ("start", "(Landroid/app/Activity;Landroid/widget/FrameLayout;F)V", unsafeBitCast(start, to: UnsafeMutableRawPointer.self)),
            ("phase", "(I)V", unsafeBitCast(phase, to: UnsafeMutableRawPointer.self)),
            ("configured", "()V", unsafeBitCast(configured, to: UnsafeMutableRawPointer.self)),
            ("insets", "(IIIII)V", unsafeBitCast(insets, to: UnsafeMutableRawPointer.self)),
            ("back", "()Z", unsafeBitCast(back, to: UnsafeMutableRawPointer.self)),
            ("frame", "(J)V", unsafeBitCast(frame, to: UnsafeMutableRawPointer.self)),
            ("clicked", "(J)V", unsafeBitCast(clicked, to: UnsafeMutableRawPointer.self)),
            ("longClicked", "(J)Z", unsafeBitCast(longClicked, to: UnsafeMutableRawPointer.self)),
            ("accessibilityActed", "(JLjava/lang/String;)Z", unsafeBitCast(accessibilityActed, to: UnsafeMutableRawPointer.self)),
            ("accessibilityStepped", "(JZ)Z", unsafeBitCast(accessibilityStepped, to: UnsafeMutableRawPointer.self)),
            ("menuChose", "(JI)V", unsafeBitCast(menuChose, to: UnsafeMutableRawPointer.self)),
            ("keyPressed", "(III)Z", unsafeBitCast(keyPressed, to: UnsafeMutableRawPointer.self)),
            ("keyTaken", "(ZIII)Z", unsafeBitCast(keyTaken, to: UnsafeMutableRawPointer.self)),
            ("gestured", "(JIIFFF)V", unsafeBitCast(gestured, to: UnsafeMutableRawPointer.self)),
            ("pressed", "(JIFF)Z", unsafeBitCast(pressed, to: UnsafeMutableRawPointer.self)),
            ("finger", "(JIIFFFFFF)Z", unsafeBitCast(finger, to: UnsafeMutableRawPointer.self)),
            ("fingers", "(JIFFFF)V", unsafeBitCast(fingers, to: UnsafeMutableRawPointer.self)),
            ("notched", "(JFF)Z", unsafeBitCast(notched, to: UnsafeMutableRawPointer.self)),
            ("focusChanged", "(JZ)V", unsafeBitCast(focusChanged, to: UnsafeMutableRawPointer.self)),
            ("destroying", "()V", unsafeBitCast(destroying, to: UnsafeMutableRawPointer.self)),
            ("environmentChanged", "()V", unsafeBitCast(environmentChanged, to: UnsafeMutableRawPointer.self)),
            ("menuOpening", "(JLandroid/view/Menu;)V", unsafeBitCast(menuOpening, to: UnsafeMutableRawPointer.self)),
            ("tabSelected", "(JI)V", unsafeBitCast(tabSelected, to: UnsafeMutableRawPointer.self)),
            ("toggled", "(JZ)V", unsafeBitCast(toggled, to: UnsafeMutableRawPointer.self)),
            ("moved", "(JI)V", unsafeBitCast(moved, to: UnsafeMutableRawPointer.self)),
            ("dragStarted", "(J)V", unsafeBitCast(dragStarted, to: UnsafeMutableRawPointer.self)),
            ("dragCompleted", "(J)V", unsafeBitCast(dragCompleted, to: UnsafeMutableRawPointer.self)),
            ("textChanged", "(JLjava/lang/String;Z)V", unsafeBitCast(textChanged, to: UnsafeMutableRawPointer.self)),
            ("heldWords", "(Ljava/lang/String;IZ)Ljava/lang/String;", unsafeBitCast(heldWords, to: UnsafeMutableRawPointer.self)),
            ("submitted", "(J)V", unsafeBitCast(submitted, to: UnsafeMutableRawPointer.self)),
            ("scrolled", "(J)V", unsafeBitCast(scrolled, to: UnsafeMutableRawPointer.self)),
            ("refreshPulled", "(J)Z", unsafeBitCast(refreshPulled, to: UnsafeMutableRawPointer.self)),
            ("held", "(JZ)V", unsafeBitCast(held, to: UnsafeMutableRawPointer.self)),
            ("opened", "(J)V", unsafeBitCast(opened, to: UnsafeMutableRawPointer.self)),
            ("closed", "(J)V", unsafeBitCast(closed, to: UnsafeMutableRawPointer.self)),
            ("fieldChose", "(JIII)V", unsafeBitCast(fieldChose, to: UnsafeMutableRawPointer.self)),
            ("chose", "(JI)V", unsafeBitCast(chose, to: UnsafeMutableRawPointer.self)),
            ("canvasTouched", "(JIFF)V", unsafeBitCast(canvasTouched, to: UnsafeMutableRawPointer.self)),
            ("answered", "(JZLjava/lang/String;)V", unsafeBitCast(answered, to: UnsafeMutableRawPointer.self)),
            ("actionChosen", "(JI)V", unsafeBitCast(actionChosen, to: UnsafeMutableRawPointer.self)),
            ("filesChosen", "(J[Ljava/lang/String;[Ljava/lang/String;Ljava/lang/String;)V",
             unsafeBitCast(filesChosen, to: UnsafeMutableRawPointer.self)),
            ("fileRead", "(J[BLjava/lang/String;)V", unsafeBitCast(fileRead, to: UnsafeMutableRawPointer.self)),
            ("requestAnswered", "(JI[Ljava/lang/String;[BLjava/lang/String;)V",
             unsafeBitCast(requestAnswered, to: UnsafeMutableRawPointer.self)),
            ("launched", "(JZ)V", unsafeBitCast(launched, to: UnsafeMutableRawPointer.self)),
            ("dragHeard", "(JILjava/lang/String;)V", unsafeBitCast(dragHeard, to: UnsafeMutableRawPointer.self)),
            ("filesDragged", "(J[Ljava/lang/String;[Ljava/lang/String;)V",
             unsafeBitCast(filesDragged, to: UnsafeMutableRawPointer.self)),
            ("webNavigating", "(JLjava/lang/String;)V", unsafeBitCast(webNavigating, to: UnsafeMutableRawPointer.self)),
            ("webNavigated", "(JILjava/lang/String;)V", unsafeBitCast(webNavigated, to: UnsafeMutableRawPointer.self)),
            ("webHistory", "(JZZ)V", unsafeBitCast(webHistory, to: UnsafeMutableRawPointer.self)),
            ("webProcessGone", "(J)V", unsafeBitCast(webProcessGone, to: UnsafeMutableRawPointer.self)),
            ("itemCell", "(JI)Landroid/view/View;", unsafeBitCast(itemCell, to: UnsafeMutableRawPointer.self)),
            ("itemHeld", "(JJLjava/lang/String;)V", unsafeBitCast(itemHeld, to: UnsafeMutableRawPointer.self)),
            ("itemShown", "(JJLjava/lang/String;)V", unsafeBitCast(itemShown, to: UnsafeMutableRawPointer.self)),
            ("itemLetGo", "(JJ)V", unsafeBitCast(itemLetGo, to: UnsafeMutableRawPointer.self)),
            ("itemsShowing", "(J[Ljava/lang/String;)V", unsafeBitCast(itemsShowing, to: UnsafeMutableRawPointer.self)),
            ("itemsDistance", "(JIIIII)I", unsafeBitCast(itemsDistance, to: UnsafeMutableRawPointer.self)),
            ("laidOut", "()V", unsafeBitCast(laidOut, to: UnsafeMutableRawPointer.self)),
            ("reportLaidOut", "()Z", unsafeBitCast(reportLaidOut, to: UnsafeMutableRawPointer.self)),
            ("measure", "(JII)J", unsafeBitCast(measure, to: UnsafeMutableRawPointer.self)),
            ("arrange", "(JII)V", unsafeBitCast(arrange, to: UnsafeMutableRawPointer.self)),
        ]

        let functions = env.pointee!.pointee
        guard let host = functions.FindClass(env, "stateui/android/StateUIHost") else {
            functions.ExceptionClear(env)
            AndroidRenderer.log.error("stateui.android.StateUIHost is missing from the application")
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

    /// The activity starts the host: it claims this thread as the UI thread, then renders first.
    /// Design: docs/design/platforms/android/runtime.md#starting
    private static func start(env: UnsafeMutablePointer<JNIEnv?>, activity: jobject, root: jobject, density: Double) {
        let core = CoreLink()
        core.claimUIThread()

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
