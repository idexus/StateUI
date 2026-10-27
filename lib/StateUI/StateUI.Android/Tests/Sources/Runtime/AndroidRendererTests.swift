// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
import StateUIConformance
import XCTest

/// A page and its counter: a click raises the count, and the caption reads it.
struct CounterPage: View {
    @State private var count = 0

    var body: some View {
        VStack {
            Text("count \(count)")
            Button("Add")
                .onClicked { count += 1 }
        }
    }
}

/// A page showing its window's phase.
struct WindowPhasePage: View {
    @Environment(\.window) private var window

    var body: some View {
        Text("\(window.phase)")
    }
}

/// A page showing what its scene keeps, which a click changes.
struct KeptSectionPage: View {
    @State(sceneKey: SceneKey<Int>("android.section")) private var section = 0

    var body: some View {
        VStack {
            Text("section \(section)")
            Button("Two")
                .onClicked { section = 2 }
        }
    }
}

/// What the host reported of the device's locale, battery and network, one label each.
struct EnvironmentPage: View {
    @Environment(\.locale) var locale
    @Environment(\.device) var device

    var body: some View {
        VStack {
            Text("locale \(locale.name) \(locale.timeZone)")
            Text("battery \(device.battery.state)")
            Text("network \(device.connectivity.networkAccess)")
        }
    }
}

/// A page showing the day the user's week starts on.
struct WeekPage: View {
    @Environment(\.locale) var locale

    var body: some View {
        Text("week \(locale.firstDayOfWeek)")
    }
}

/// A page showing what the device is called.
struct DevicePage: View {
    @Environment(\.device) var device

    var body: some View {
        Text("device \(device.info.name)")
    }
}

final class AndroidRendererTests: XCTestCase {
    static var allTests: [(String, (AndroidRendererTests) -> () throws -> Void)] {
        [
            ("testThePageShowsItsControlsInTheRoot", testThePageShowsItsControlsInTheRoot),
            ("testAClickRendersWhatItsHandlerChanged", testAClickRendersWhatItsHandlerChanged),
            ("testAControlNoRegistrationAnswersShowsItsName", testAControlNoRegistrationAnswersShowsItsName),
            ("testAnActivityMadeAgainShowsTheSceneWithItsState", testAnActivityMadeAgainShowsTheSceneWithItsState),
            ("testAnActivityMadeAgainLeavesItsWindowsPhaseAlone", testAnActivityMadeAgainLeavesItsWindowsPhaseAlone),
            ("testANewDensityMakesTheWindowAgainInIt", testANewDensityMakesTheWindowAgainInIt),
            ("testAQuestionWaitingAsTheActivityFinishesIsDismissedOnceItsWindowWent", testAQuestionWaitingAsTheActivityFinishesIsDismissedOnceItsWindowWent),
            ("testAQuestionWaitingAsTheActivityIsMadeAgainIsAnsweredInTheNext", testAQuestionWaitingAsTheActivityIsMadeAgainIsAnsweredInTheNext),
            ("testTheDeviceIsCalledWhatItsUserNamedIt", testTheDeviceIsCalledWhatItsUserNamedIt),
            ("testAnActivityAfterBackShowsANewScene", testAnActivityAfterBackShowsANewScene),
            ("testASceneComesBackAtTheNextStartWithWhatItKept", testASceneComesBackAtTheNextStartWithWhatItKept),
            ("testAnActivityMadeAgainKeepsWhatTheScenesKept", testAnActivityMadeAgainKeepsWhatTheScenesKept),
            ("testAStartedHostSaysWhatItRealizes", testAStartedHostSaysWhatItRealizes),
            ("testTheWindowsTitleNamesTheActivity", testTheWindowsTitleNamesTheActivity),
            ("testTheHostReportsTheLocaleTheBatteryAndTheNetwork", testTheHostReportsTheLocaleTheBatteryAndTheNetwork),
            ("testTheHostReportsTheAccessibilitySettings", testTheHostReportsTheAccessibilitySettings),
            ("testTheEnvironmentReachesTheHostOnTheUIThreadWhicheverThreadTellsIt", testTheEnvironmentReachesTheHostOnTheUIThreadWhicheverThreadTellsIt),
            ("testTheLocaleIsTheHostLayersReadingOfTheRelaysWords", testTheLocaleIsTheHostLayersReadingOfTheRelaysWords),
        ]
    }

    func testThePageShowsItsControlsInTheRoot() {
        onMainActor {
            let host = AndroidRenderer.running { CounterPage() }

            XCTAssertEqual(host.views(AndroidTextView.self).map(\.text), ["count 0"])
            XCTAssertEqual(host.views(AndroidButtonView.self).map(\.text), ["Add"])
            XCTAssertEqual(Java.callInt(host.root.reference, TestJava.getChildCount), 1)
        }
    }

    /// The proof of the host's spine: the click reaches the handler, the state it wrote renders, and the patch reaches the view.
    func testAClickRendersWhatItsHandlerChanged() throws {
        try onMainActor {
            let host = AndroidRenderer.running { CounterPage() }
            let button = try XCTUnwrap(host.views(AndroidButtonView.self).first)

            button.click()
            button.click()

            XCTAssertEqual(host.views(AndroidTextView.self).map(\.text), ["count 2"])
        }
    }

    func testAControlNoRegistrationAnswersShowsItsName() {
        onMainActor {
            let host = AndroidRenderer.running { VStack { Map() } }

            XCTAssertEqual(host.views(AndroidUnsupportedView.self).map(\.text), ["Android: unsupported Map"])
        }
    }

    /// Android makes an activity again - a new configuration - while its scene stands: the next activity shows
    /// the scene the first showed, with its state, rather than a second scene.
    func testAnActivityMadeAgainShowsTheSceneWithItsState() throws {
        try onMainActor {
            let first = AndroidRenderer.running { CounterPage() }
            try XCTUnwrap(first.views(AndroidButtonView.self).first).click()

            let second = AndroidRenderer.start(context: TestContext.context, root: TestJava.root(), density: 2)

            XCTAssertEqual(second.runtime.tree.root?.children.filter { $0.type == .scene }.count, 1)
            XCTAssertEqual(second.views(AndroidTextView.self).map(\.text), ["count 1"])
            XCTAssertEqual(Java.callInt(second.root.reference, TestJava.getChildCount), 1)
        }
    }

    /// An activity Android makes again for a new configuration - a theme the application or the system chose -
    /// pauses and stops on its way, and its window hears nothing of it: the next resumes at once. An activity that
    /// stops for good leaves its window stopped.
    func testAnActivityMadeAgainLeavesItsWindowsPhaseAlone() throws {
        try onMainActor {
            let first = AndroidRenderer.running { WindowPhasePage() }
            first.setPhase(.active)
            let shown = { (host: AndroidRenderer) -> [String] in
                host.runtime.pump.turn()
                TestWindow.run(for: 20)
                return host.views(AndroidTextView.self).map(\.text)
            }
            XCTAssertEqual(shown(first), ["activated"])

            first.setPhase(.inactive, beingMadeAgain: true)
            first.setPhase(.background, beingMadeAgain: true)
            XCTAssertEqual(shown(first), ["activated"], "the window stands as it stood")
            let second = AndroidRenderer.start(context: TestContext.context, root: TestJava.root(), density: 2)
            second.setPhase(.active)
            XCTAssertEqual(shown(second), ["activated"], "and stands so in the next")

            second.setPhase(.inactive)
            second.setPhase(.background)
            XCTAssertEqual(shown(second), ["stopped"], "stopped for good")
        }
    }

    /// A question waiting as Android makes its activity again is asked again in the next - its dialog went with the
    /// first - and the answer given there reaches the handler that asked: acts are the process's.
    func testAQuestionWaitingAsTheActivityIsMadeAgainIsAnsweredInTheNext() throws {
        try onMainActor {
            let answers = Received<Bool>()
            let first = AndroidRenderer.running {
                Button("Ask").onClicked(.ignoreWhileRunning) {
                    answers.values.append(try await WindowSession().confirm("Sure?", message: "Both", accept: "Yes", cancel: "No"))
                }
            }
            try XCTUnwrap(first.views(AndroidButtonView.self).first).click()
            first.settle { Self.asked() != nil }
            XCTAssertEqual(Self.asked(), "Sure?")

            Java.callStatic(AndroidDriver.dialogs, Self.leaveAll)
            let second = AndroidRenderer.start(context: TestContext.context, root: TestJava.root(), density: 2)
            second.settle { Self.asked() != nil }
            XCTAssertEqual(Self.asked(), "Sure?", "asked again in the next")

            let pressed = Java.frame {
                Java.callStaticBool(
                    AndroidDriver.dialogs, AndroidDriver.answer, .int(AndroidAnswer.accept.rawValue), .int(-1),
                    .object(nil))
            }
            XCTAssertTrue(pressed)
            // The dialog hands its button's press on in a message of the UI thread's own.
            second.settle {
                TestWindow.run(for: 10)
                return !answers.values.isEmpty
            }
            XCTAssertEqual(answers.values, [true])
        }
    }

    /// The title of the question the user meets now, where one shows.
    @MainActor
    private static func asked() -> String? {
        Java.frame {
            guard let asked = Java.callStaticObject(AndroidDriver.dialogs, AndroidDriver.question) else { return nil }
            return Java.jni.GetObjectArrayElement(Java.env, asked, 0).map { Java.text($0) }
        }
    }

    @MainActor private static let leaveAll = Java.staticMethod(AndroidDriver.dialogs, "leaveAll", "()V")

    /// A question waiting as Back finishes the activity is answered as dismissed once its window went, every time:
    /// its handler hears it, a write of its run is refused, and the next activity of the process finds nothing
    /// waiting before what it asks.
    func testAQuestionWaitingAsTheActivityFinishesIsDismissedOnceItsWindowWent() throws {
        try onMainActor {
            let heard = Heard()
            let written = Received<Bool>()
            let host = AndroidRenderer.running {
                Button("Ask").onClicked(.ignoreWhileRunning) {
                    do {
                        let answer = try await WindowSession()
                            .confirm("Sure?", message: "", accept: "Yes", cancel: "No")
                        heard.words.append("\(answer)")
                        written.values.append(answer)
                    } catch {
                        heard.words.append("threw \(error)")
                    }
                }
            }
            let button = try XCTUnwrap(host.views(AndroidButtonView.self).first)
            button.click()
            host.settle { Self.asked() != nil }
            XCTAssertEqual(Self.asked(), "Sure?", "the question shows")
            let said = Said.shared.everySaid.count

            host.destroying()
            host.settle { !heard.words.isEmpty }

            XCTAssertEqual(heard.words, ["false"], "answered as dismissed; " + Self.waiting(saidSince: said))
            XCTAssertEqual(written.values, [], "its run went with the window")
            let refused = Said.shared.everySaid.dropFirst(said).contains { $0.contains("superseded") }
            XCTAssertTrue(refused, "its write refused; " + Self.waiting(saidSince: said))
            Java.callStatic(AndroidDriver.dialogs, AndroidDriver.dismissAll)
        }
    }

    /// What a handler heard, kept by reference rather than in a state: a run its element outlived writes no state.
    private final class Heard: @unchecked Sendable {
        var words: [String] = []
    }

    /// What still waits in the core - replies, handlers resumed and not run, jobs - and what it said since `first`:
    /// where an answer stopped on its way to its handler.
    @MainActor
    private static func waiting(saidSince first: Int) -> String {
        "\(Renderer.shared.completions.count) replies, \(Renderer.shared.resumesPending) resumes and "
            + "\(UIThreadExecutor.shared.pendingCount) jobs waiting; said \(Said.shared.everySaid.dropFirst(first))"
    }

    /// Pixels a point changing - the display's size, another screen - make the window again at the new density, as
    /// an activity Android makes again: no view is laid out in one scale and measured in another.
    func testANewDensityMakesTheWindowAgainInIt() throws {
        try onMainActor {
            let first = AndroidRenderer.running { CounterPage() }
            try XCTUnwrap(first.views(AndroidButtonView.self).first).click()
            let density = AndroidEnvironment.density(of: TestContext.context.reference)
            guard density != first.density else { throw XCTSkip("the device stands at the test's density") }

            first.configured()

            let now = try XCTUnwrap(AndroidRenderer.shared)
            XCTAssertEqual(now.density, density)
            XCTAssertEqual(now.views(AndroidTextView.self).map(\.text), ["count 1"], "the scene with its state")
            XCTAssertEqual(Java.callInt(now.root.reference, TestJava.getChildCount), 1, "the window once")
        }
    }

    /// The process outlives its activity: Back finishes it, and its window and scene hear they are going. The
    /// launcher's next activity shows a new scene, as the first one did, not an empty window.
    func testAnActivityAfterBackShowsANewScene() throws {
        try onMainActor {
            let first = AndroidRenderer.running { CounterPage() }
            try XCTUnwrap(first.views(AndroidButtonView.self).first).click()
            first.destroying()

            let second = AndroidRenderer.start(context: TestContext.context, root: TestJava.root(), density: 2)

            XCTAssertEqual(second.runtime.tree.root?.children.filter { $0.type == .scene }.count, 1)
            XCTAssertEqual(second.views(AndroidTextView.self).map(\.text), ["count 0"])
            XCTAssertEqual(Java.callInt(second.root.reference, TestJava.getChildCount), 1)
        }
    }

    /// The platform restores no windows: a value a scene keeps is kept with the scenes beside the preferences, and
    /// comes back with its scene at the process's next start.
    func testASceneComesBackAtTheNextStartWithWhatItKept() throws {
        try onMainActor {
            let first = AndroidRenderer.running { KeptSectionPage() }
            try XCTUnwrap(first.views(AndroidButtonView.self).first).click()
            XCTAssertEqual(first.views(AndroidTextView.self).map(\.text), ["section 2"])
            first.runtime.tree.root?.leave()

            stateUIUseApp(OneWindowApplication { KeptSectionPage() })
            let next = AndroidRenderer.bare()
            next.start()

            XCTAssertEqual(next.views(AndroidTextView.self).map(\.text), ["section 2"])
        }
    }

    /// What the scenes keep outlives the activity: Android making it again hands the scenes kept to the next, which
    /// keeps them on.
    func testAnActivityMadeAgainKeepsWhatTheScenesKept() throws {
        try onMainActor {
            let first = AndroidRenderer.running { KeptSectionPage() }
            try XCTUnwrap(first.views(AndroidButtonView.self).first).click()

            let second = AndroidRenderer.start(context: TestContext.context, root: TestJava.root(), density: 2)

            let kept = AndroidPersistence.readScenes(context: TestContext.context.reference)
            XCTAssertEqual(second.views(AndroidTextView.self).map(\.text), ["section 2"])
            XCTAssertEqual(kept.scenes.map(\.values), [["android.section": .string("2")]])
        }
    }

    /// A started host tells the core what it realizes: the library's elements it shows, and not those it shows
    /// as unsupported.
    func testAStartedHostSaysWhatItRealizes() {
        onMainActor {
            _ = AndroidRenderer.running { CounterPage() }
            HostBoundary.setRealization(HostRealization())

            _ = AndroidRenderer.start(context: TestContext.context, root: TestJava.root(), density: 2)

            XCTAssertTrue(HostBoundary.realizes(TextContract.self))
            XCTAssertTrue(HostBoundary.realizes(ButtonContract.self))
            XCTAssertFalse(HostBoundary.realizes(MapContract.self))
        }
    }

    /// The device is called what its user named it in Settings - "Skorpio 01" - not its model's code name, the same
    /// on every device of that model.
    func testTheDeviceIsCalledWhatItsUserNamedIt() throws {
        try onMainActor {
            let named = try XCTUnwrap(Self.nameInSettings)
            stateUIUseApp(OneWindowApplication(page: { DevicePage() }))
            let host = AndroidRenderer.start(context: TestContext.window, root: TestJava.root(), density: 2)

            XCTAssertEqual(host.views(AndroidTextView.self).map(\.text), ["device \(named)"])
        }
    }

    /// The name the user gave the device in Settings; nil where there is none.
    @MainActor
    private static var nameInSettings: String? {
        Java.frame {
            let settings = Java.findClass("android/provider/Settings$Global")
            let getString = Java.staticMethod(
                settings, "getString", "(Landroid/content/ContentResolver;Ljava/lang/String;)Ljava/lang/String;")
            let resolver = Java.callObject(
                TestContext.context.reference,
                Java.method(JavaAPI.contextClass, "getContentResolver", "()Landroid/content/ContentResolver;"))
            return Java.callStaticObject(settings, getString, .object(resolver), .object(Java.string("device_name")))
                .map { Java.text($0) }
        }
    }

    /// Before the first render the host tells the core the device's locale, its battery and its network.
    func testTheHostReportsTheLocaleTheBatteryAndTheNetwork() {
        onMainActor {
            let host = AndroidRenderer.running { EnvironmentPage() }
            let texts = host.views(AndroidTextView.self).map(\.text)

            XCTAssertEqual(texts.count, 3)
            XCTAssertFalse(texts.first?.hasPrefix("locale  ") ?? true, "\(texts)")
            XCTAssertFalse(texts.contains("battery unknown"), "\(texts)")
            XCTAssertFalse(texts.contains("network unknown"), "\(texts)")
        }
    }

    /// Android tells some of what the environment watch hears on a thread of its own - the animations' scale on a
    /// binder's: each listener reaches the host on the UI thread, whichever thread tells it.
    func testTheEnvironmentReachesTheHostOnTheUIThreadWhicheverThreadTellsIt() throws {
        try onMainActor {
            _ = AndroidRenderer.running { Text("Watched") }
            let context = TestContext.context.reference
            let watch = try XCTUnwrap(Java.callStaticObject(JavaAPI.environment, EnvironmentWatch.watch, .object(context)))
            defer {
                Java.callStatic(JavaAPI.environment, EnvironmentWatch.unwatch, .object(context), .object(watch))
                Java.release(local: watch)
            }

            Java.callStatic(EnvironmentWatch.test, EnvironmentWatch.tellOffTheUIThread, .object(context), .object(watch))
            TestWindow.run(for: 50)

            XCTAssertNotNil(AndroidRenderer.shared, "the host heard each change, and stands")
        }
    }

    /// The accessibility settings reported are the device's: less motion where the system's animations are off, as
    /// the renderer reads them for its own motion, no screen reader under a test, and the scale of the system's words.
    func testTheHostReportsTheAccessibilitySettings() {
        onMainActor {
            HostBoundary.setAccessibilityInfo(HostAccessibilityInfo(
                reducesMotion: !AndroidRenderer.animationsRemoved(), prefersHigherContrast: false,
                isScreenReaderOn: true, textScale: 0))
            _ = AndroidRenderer.running { Text("Settings") }
            let settings = StandardEnvironment.device.accessibility

            XCTAssertEqual(settings.reducesMotion, AndroidRenderer.animationsRemoved())
            XCTAssertFalse(settings.isScreenReaderOn)
            XCTAssertGreaterThan(settings.textScale, 0.5)
        }
    }
}

extension AndroidRendererTests {
    /// The locale is the host layer's reading of the relay's words - its week starting on the day they name from
    /// Sunday's 0, as on every host.
    func testTheLocaleIsTheHostLayersReadingOfTheRelaysWords() throws {
        try onMainActor {
            let host = AndroidRenderer.running { WeekPage() }
            let words = Java.frame {
                Java.texts(Java.callStaticObject(
                    JavaAPI.environment, JavaAPI.localeFacts, .object(TestContext.context.reference)))
            }
            let locale = try XCTUnwrap(HostLocaleInfo(words: words), "\(words)")

            XCTAssertEqual(host.views(AndroidTextView.self).map(\.text), ["week \(locale.firstDayOfWeek)"])
        }
    }

    /// The window's title is what the activity - and its task among the recent ones - is called.
    func testTheWindowsTitleNamesTheActivity() {
        onMainActor {
            let host = AndroidRenderer.running { TitlingPage(title: "Notes") }
            XCTAssertEqual(host.windowTitle, .some("Notes"))
        }
    }
}

/// A page that names its window.
private struct TitlingPage: View {
    @Environment(\.window) private var window
    let title: String

    var body: some View {
        let window = self.window
        let title = self.title
        return Text(title).onCreated { window.title = title }
    }
}

/// The host's watch on the environment, and the test's own teller of it.
@MainActor
private enum EnvironmentWatch {
    static let watch = Java.staticMethod(JavaAPI.environment, "watch", "(Landroid/content/Context;)[Ljava/lang/Object;")
    static let unwatch = Java.staticMethod(
        JavaAPI.environment, "unwatch", "(Landroid/content/Context;[Ljava/lang/Object;)V")
    static let test = Java.findClass("stateui/android/test/TestEnvironment")
    static let tellOffTheUIThread = Java.staticMethod(
        test, "tellOffTheUIThread", "(Landroid/content/Context;[Ljava/lang/Object;)V")
}
