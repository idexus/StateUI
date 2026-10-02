// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
import StateUIConformance
import XCTest

/// A page and its counter: a click raises the count, and the caption reads it.
struct CounterPage: ContentView {
    @State private var count = 0

    var content: some View {
        VStack {
            Text("count \(count)")
            Button("Add")
                .onClicked { count += 1 }
        }
    }
}

/// What the host reported of the device's locale, battery and network, one label each.
struct EnvironmentPage: ContentView {
    @Environment var locale: LocaleInfo
    @Environment var battery: Battery
    @Environment var connectivity: Connectivity

    var content: some View {
        VStack {
            Text("locale \(locale.name) \(locale.timeZone)")
            Text("battery \(battery.state)")
            Text("network \(connectivity.networkAccess)")
        }
    }
}

/// A page showing what the device is called.
struct DevicePage: ContentView {
    @Environment var device: DeviceInfo

    var content: some View {
        Text("device \(device.name)")
    }
}

final class AndroidRendererTests: XCTestCase {
    static var allTests: [(String, (AndroidRendererTests) -> () throws -> Void)] {
        [
            ("testThePageShowsItsControlsInTheRoot", testThePageShowsItsControlsInTheRoot),
            ("testAClickRendersWhatItsHandlerChanged", testAClickRendersWhatItsHandlerChanged),
            ("testAControlNoRegistrationAnswersShowsItsName", testAControlNoRegistrationAnswersShowsItsName),
            ("testAnActivityMadeAgainShowsTheSceneWithItsState", testAnActivityMadeAgainShowsTheSceneWithItsState),
            ("testTheDeviceIsCalledWhatItsUserNamedIt", testTheDeviceIsCalledWhatItsUserNamedIt),
            ("testAnActivityAfterBackShowsANewScene", testAnActivityAfterBackShowsANewScene),
            ("testAStartedHostSaysWhatItRealizes", testAStartedHostSaysWhatItRealizes),
            ("testTheWindowsTitleNamesTheActivity", testTheWindowsTitleNamesTheActivity),
            ("testTheHostReportsTheLocaleTheBatteryAndTheNetwork", testTheHostReportsTheLocaleTheBatteryAndTheNetwork),
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
}

extension AndroidRendererTests {
    /// The window's title is what the activity - and its task among the recent ones - is called.
    func testTheWindowsTitleNamesTheActivity() {
        onMainActor {
            let host = AndroidRenderer.running { TitledWindowPage(title: "Notes") }
            XCTAssertEqual(host.windowTitle, .some("Notes"))
        }
    }
}

/// A page that names its window.
private struct TitledWindowPage: ContentView {
    @Environment private var window: WindowSession
    let title: String

    var content: some View {
        let window = self.window
        let title = self.title
        return Text(title).onCreated { window.title = title }
    }
}
