// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import XCTest

@MainActor
final class AppKitSessionTests: XCTestCase {
    @MainActor
    func testApplicationScenesOwnAllOfTheirNativeWindows() {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(
            scene("1", windows: [window("window 1"), window("fonts 2", kind: "fonts")]),
            scene("2", windows: [window("window 1")])
        ))

        XCTAssertEqual(renderer.sceneCountForTesting, 2)
        XCTAssertEqual(renderer.windowsForTesting.count, 3)
        XCTAssertEqual(renderer.windowsForTesting.compactMap { $0.element?.enclosing(type: .scene)?.id }, [
            .manual("1"), .manual("1"), .manual("2"),
        ])
        XCTAssertTrue(renderer.windowsForTesting.compactMap(\.window).allSatisfy(NSApp.windows.contains))
    }

    /// A window keeps nothing in the application's preferences: the system's restoration keeps a restored window's
    /// frame, and every window opened and moved would otherwise leave a key there for good.
    @MainActor
    func testAWindowLeavesNothingInThePreferences() {
        let kept = { UserDefaults.standard.dictionaryRepresentation().keys.filter { $0.hasPrefix("NSWindow Frame") } }
        let before = Set(kept())
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        renderer.applyForTesting(tree(scene("1", windows: [window("window 1"), window("fonts 2", kind: "fonts")])))
        for controller in renderer.windowsForTesting {
            controller.window?.setFrame(NSRect(x: 40, y: 40, width: 320, height: 240), display: false)
        }
        renderer.closeForTesting()

        XCTAssertEqual(Set(kept()).subtracting(before), [])
    }

    @MainActor
    func testRemovingOneWindowClosesOnlyThatNativeWindow() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        renderer.applyForTesting(tree(
            scene("1", windows: [window("window 1"), window("fonts 2", kind: "fonts")]),
            scene("2", windows: [window("window 1")])
        ))
        let first = try XCTUnwrap(renderer.windowsForTesting.first?.window)
        let tool = try XCTUnwrap(renderer.windowsForTesting.dropFirst().first?.window)
        let closing = ClosingWatch()
        defer { closing.stop() }

        renderer.applyForTesting(tree(
            scene("1", windows: [window("window 1")]),
            scene("2", windows: [window("window 1")])
        ))

        XCTAssertEqual(renderer.windowsForTesting.count, 2)
        XCTAssertTrue(renderer.windowsForTesting.first?.window === first)
        XCTAssertEqual(closing.closed, [ObjectIdentifier(tool)])
    }

    /// A window the system restored comes back as its kind, in that very window, carrying what its scene keeps -
    /// whatever order the system restores them in; one of a kind no scene declares is not restored.
    @MainActor
    func testAWindowTheSystemRestoredComesBackInThatVeryWindow() async throws {
        stateUIUseApp(AppKitSessionApp())
        let firstHost = testRenderer(resourceDirectory: nil, presentsWindows: false)
        firstHost.startForTesting()
        try await StandardEnvironment.application.openWindow(.appKitTestTool)
        firstHost.runtime.pump.turn()
        firstHost.keepSceneValue(HostActCall(
            act: .persistSceneValue, arguments: [.name("1"), .name("shade"), .string("dusk")], completion: nil))
        let records = firstHost.windowsForTesting.map(\.restorationRecordForTesting)
        firstHost.closeForTesting()
        XCTAssertEqual(records.map(\.kind), [nil, "appkit.test.tool"])

        stateUIUseApp(AppKitSessionApp())
        let restoredHost = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { restoredHost.closeForTesting() }
        let tool = try XCTUnwrap(restoredHost.acceptRestoredWindow(records[1]))
        let window = try XCTUnwrap(restoredHost.acceptRestoredWindow(records[0]))
        XCTAssertNil(restoredHost.acceptRestoredWindow(WindowRecord(identifier: "gone", kind: "appkit.test.gone")))
        restoredHost.startForTesting()

        let controllers = restoredHost.windowsForTesting
        XCTAssertEqual(controllers.count, 2)
        XCTAssertEqual(restoredHost.sceneCountForTesting, 1)
        XCTAssertTrue(controllers[0].window === tool)
        XCTAssertTrue(controllers[1].window === window)
        XCTAssertEqual(controllers.map(\.restorationRecordForTesting.identifier), [records[1].identifier, records[0].identifier])
        XCTAssertEqual(controllers.map(\.restorationRecordForTesting.kept), [["shade": .string("dusk")], ["shade": .string("dusk")]])
    }

    @MainActor
    func testARestoredWindowKeepsItsFrameWhenNoGeometryIsRequested() throws {
        stateUIUseApp(AppKitSessionApp())
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        let record = WindowRecord(identifier: UUID().uuidString)
        let restored = try XCTUnwrap(renderer.acceptRestoredWindow(record))
        restored.setFrame(
            NSRect(x: 137, y: 211, width: 733, height: 577),
            display: false)
        restored.contentMinSize = NSSize(width: 320, height: 240)
        restored.contentMaxSize = NSSize(width: 1_200, height: 900)
        restored.standardWindowButton(.zoomButton)?.isEnabled = false
        restored.styleMask.remove(.miniaturizable)
        let standing = restored.frame

        renderer.startForTesting()

        XCTAssertTrue(renderer.windowsForTesting.first?.window === restored)
        XCTAssertEqual(restored.frame, standing)
        XCTAssertEqual(restored.contentMinSize, NSSize(width: 320, height: 240))
        XCTAssertEqual(restored.contentMaxSize, NSSize(width: 1_200, height: 900))
        XCTAssertFalse(restored.standardWindowButton(.zoomButton)?.isEnabled ?? true)
        XCTAssertFalse(restored.styleMask.contains(.miniaturizable))
        XCTAssertFalse(
            restored.delegate?.windowShouldZoom?(restored, toFrame: restored.frame) ?? true)
    }

    @MainActor
    func testWindowGeometryRequestsDoNotReplayUnchangedAxes() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var initial = window("window 1")
        initial.properties[.width] = .number(640)
        initial.properties[.height] = .number(480)
        renderer.applyForTesting(tree(scene("1", windows: [initial])))

        let native = try XCTUnwrap(renderer.windowsForTesting.first?.window)
        native.setContentSize(NSSize(width: 700, height: 550))
        native.setFrameOrigin(NSPoint(x: 137, y: 211))

        var width = HostPatch(id: .manual("window 1"), type: .window)
        width.properties[.width] = .number(820)
        renderer.applyForTesting(tree(scene("1", windows: [width])))

        var contentSize = native.contentRect(forFrameRect: native.frame).size
        XCTAssertEqual(contentSize.width, 820, accuracy: 0.001)
        XCTAssertEqual(contentSize.height, 550, accuracy: 0.001)
        XCTAssertEqual(native.frame.minX, 137, accuracy: 0.001)

        var relinquishedWidth = HostPatch(id: .manual("window 1"), type: .window)
        relinquishedWidth.clearedProperties = [.width]
        native.setContentSize(NSSize(width: 910, height: 610))
        renderer.applyForTesting(tree(scene("1", windows: [relinquishedWidth])))

        contentSize = native.contentRect(forFrameRect: native.frame).size
        XCTAssertEqual(contentSize.width, 910, accuracy: 0.001)
        XCTAssertEqual(contentSize.height, 610, accuracy: 0.001)

        let x = native.frame.minX
        let screen = try XCTUnwrap(native.screen ?? NSScreen.main)
        var y = HostPatch(id: .manual("window 1"), type: .window)
        y.properties[.y] = .number(73)
        renderer.applyForTesting(tree(scene("1", windows: [y])))

        XCTAssertEqual(native.frame.minX, x, accuracy: 0.001)
        XCTAssertEqual(native.frame.maxY, screen.visibleFrame.maxY - 73, accuracy: 0.001)
    }

    @MainActor
    func testWindowMapsAndClearsItsCompleteNativePropertyGroup() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var authored = window("window 1")
        authored.properties.merge([
            .title: .string("Workspace"),
            .x: .number(137),
            .y: .number(73),
            .width: .number(640),
            .height: .number(480),
            .minimumWidth: .number(320),
            .minimumHeight: .number(240),
            .maximumWidth: .number(1_200),
            .maximumHeight: .number(900),
            .isMaximizable: .bool(false),
            .isMinimizable: .bool(false),
        ]) { _, authored in authored }
        renderer.applyForTesting(tree(scene("1", windows: [authored])))

        let controller = try XCTUnwrap(renderer.windowsForTesting.first)
        let native = try XCTUnwrap(controller.window)
        let screen = try XCTUnwrap(native.screen ?? NSScreen.main)
        // The content area is what the title bar and toolbar leave; AppKit's
        // content view reaches under them by this much.
        let contentSize = native.contentLayoutRect.size
        let chrome = native.frame.height - native.contentLayoutRect.height

        XCTAssertEqual(native.title, "Workspace")
        XCTAssertGreaterThan(chrome, 0)
        XCTAssertEqual(contentSize.width, 640, accuracy: 0.001)
        XCTAssertEqual(contentSize.height, 480, accuracy: 0.001)
        XCTAssertEqual(native.frame.minX, 137, accuracy: 0.001)
        XCTAssertEqual(native.frame.maxY, screen.visibleFrame.maxY - 73, accuracy: 0.001)
        XCTAssertEqual(native.contentMinSize, NSSize(width: 320, height: 240 + chrome))
        XCTAssertEqual(native.contentMaxSize, NSSize(width: 1_200, height: 900 + chrome))
        XCTAssertTrue(native.collectionBehavior.contains(.fullScreenNone), "a bounded window takes no full screen")
        XCTAssertFalse(try XCTUnwrap(native.standardWindowButton(.zoomButton)).isEnabled)
        XCTAssertFalse(native.styleMask.contains(.miniaturizable))
        XCTAssertFalse(
            native.delegate?.windowShouldZoom?(native, toFrame: native.frame) ?? true)

        let standingFrame = native.frame
        var cleared = HostPatch(id: .manual("window 1"), type: .window)
        cleared.clearedProperties = [
            .title, .x, .y, .width, .height,
            .minimumWidth, .minimumHeight, .maximumWidth, .maximumHeight,
            .isMaximizable, .isMinimizable,
        ]
        renderer.applyForTesting(tree(scene("1", windows: [cleared])))

        XCTAssertEqual(native.title, "StateUI")
        XCTAssertEqual(native.frame, standingFrame)
        XCTAssertEqual(native.contentMinSize, .zero)
        let unbounded = CGFloat(Float.greatestFiniteMagnitude)
        XCTAssertEqual(native.contentMaxSize, NSSize(width: unbounded, height: unbounded))
        XCTAssertFalse(native.collectionBehavior.contains(.fullScreenNone), "unbounded, it takes the full screen again")
        XCTAssertTrue(try XCTUnwrap(native.standardWindowButton(.zoomButton)).isEnabled)
        XCTAssertTrue(native.styleMask.contains(.miniaturizable))
        XCTAssertTrue(native.delegate?.windowShouldZoom?(native, toFrame: native.frame) ?? true)
    }

    @MainActor
    func testWindowMinimumWinsAContradictoryMaximum() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var authored = window("window 1")
        authored.properties[.minimumWidth] = .number(640)
        authored.properties[.maximumWidth] = .number(320)
        renderer.applyForTesting(tree(scene("1", windows: [authored])))

        let native = try XCTUnwrap(renderer.windowsForTesting.first?.window)
        XCTAssertEqual(native.contentMinSize.width, 640)
        XCTAssertEqual(native.contentMaxSize.width, 640)
    }

    @MainActor
    func testAWindowOfAKindMapsAndClearsItsCompleteNativeMetadataGroup() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false)
        defer { renderer.closeForTesting() }

        var tool = window("tool", kind: "notes.inspector", eventBase: 300)
        tool.properties[.windowValue] = .string("selection-7")
        tool.properties[.hidesWhenInactive] = .bool(true)
        tool.properties[.floatsOnTop] = .bool(true)
        renderer.applyForTesting(tree(
            scene("1", windows: [window("window 1"), tool]),
            scene("2", windows: [window("window 1")])
        ))

        let controller = try XCTUnwrap(renderer.windowsForTesting.dropFirst().first)
        let native = try XCTUnwrap(controller.window)

        XCTAssertEqual(controller.restorationRecordForTesting.kind, "notes.inspector")
        XCTAssertEqual(controller.restorationRecordForTesting.value, "selection-7")
        XCTAssertEqual(native.level, .floating)

        var cleared = HostPatch(id: .manual("tool"), type: .window)
        cleared.clearedProperties = [.windowValue, .hidesWhenInactive, .floatsOnTop]
        renderer.applyForTesting(tree(
            scene("1", windows: [window("window 1"), cleared]),
            scene("2", windows: [window("window 1")])
        ))

        XCTAssertEqual(controller.restorationRecordForTesting.kind, "notes.inspector")
        XCTAssertNil(controller.restorationRecordForTesting.value)
        XCTAssertEqual(native.level, .normal)
    }

    /// A value a scene keeps is written in the record of every window of it - whichever the system brings back first
    /// opens the scene with it - and of a window it opens later; another scene's windows keep their own.
    @MainActor
    func testASceneValueIsKeptInEveryWindowOfItsScene() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        renderer.applyForTesting(tree(
            scene("1", windows: [window("window 1"), window("fonts 2", kind: "fonts")]),
            scene("2", windows: [window("window 1")])
        ))

        renderer.keepSceneValue(HostActCall(
            act: .persistSceneValue,
            arguments: [.name("1"), .name("shade"), .string("dusk")],
            completion: nil))
        renderer.applyForTesting(tree(
            scene("1", windows: [window("window 1"), window("fonts 2", kind: "fonts"), window("window 3")]),
            scene("2", windows: [window("window 1")])
        ))

        XCTAssertEqual(renderer.windowsForTesting.map(\.restorationRecordForTesting.kept), [
            ["shade": .string("dusk")], ["shade": .string("dusk")], ["shade": .string("dusk")], [:],
        ])
    }

    /// A window the system restored of another scene's kind takes the place of the window launch opens: what the
    /// system kept is what stands, in the very window it restored.
    @MainActor
    func testARestoredWindowOfAnotherSceneTakesTheLaunchWindowsPlace() throws {
        stateUIUseApp(AppKitKindsApp())
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        let restored = renderer.acceptRestoredWindow(
            WindowRecord(identifier: "restored-editor", kind: "appkit.test.editor"))
        renderer.startForTesting()

        let controller = try XCTUnwrap(renderer.windowsForTesting.first)
        XCTAssertEqual(renderer.windowsForTesting.count, 1)
        XCTAssertTrue(controller.window === restored)
        XCTAssertEqual(controller.element?.value(.windowType)?.name, "appkit.test.editor")
        XCTAssertEqual(controller.restorationRecordForTesting.kind, "appkit.test.editor")
    }

    /// *File ▸ New Window* and `openWindow()` each open one more window of the group with no name, in the scene
    /// standing; a window another scene declares opens that scene.
    @MainActor
    func testNewWindowAndOpenWindowEachOpenOneMore() async throws {
        stateUIUseApp(AppKitKindsApp())
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        renderer.startForTesting()
        XCTAssertEqual(renderer.windowsForTesting.count, 1)

        renderer.openNewWindow()
        try await StandardEnvironment.application.openWindow()
        renderer.runtime.pump.turn()
        XCTAssertEqual(renderer.windowsForTesting.count, 3)
        XCTAssertEqual(renderer.sceneCountForTesting, 1)

        try await StandardEnvironment.application.openWindow(.appKitTestEditor)
        renderer.runtime.pump.turn()
        XCTAssertEqual(renderer.windowsForTesting.count, 4)
        XCTAssertEqual(renderer.sceneCountForTesting, 2)
        XCTAssertEqual(StandardEnvironment.application.scenes.count, 2)
    }

    /// The user closing a window closes that one alone - its scene stands while a window of it does - and closing
    /// the last ends the scene.
    @MainActor
    func testClosingANativeWindowEndsItsSceneWithTheLast() async throws {
        stateUIUseApp(AppKitSessionApp())
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        renderer.startForTesting()
        try await StandardEnvironment.application.openWindow(.appKitTestTool)
        renderer.runtime.pump.turn()
        let tool = try XCTUnwrap(renderer.windowsForTesting.last?.window)

        renderer.windowsForTesting[0].windowWillClose(Notification(name: NSWindow.willCloseNotification))

        XCTAssertEqual(renderer.sceneCountForTesting, 1)
        XCTAssertTrue(renderer.windowsForTesting.map(\.window) == [tool])

        renderer.windowsForTesting[0].windowWillClose(Notification(name: NSWindow.willCloseNotification))

        XCTAssertEqual(renderer.sceneCountForTesting, 0)
        XCTAssertTrue(StandardEnvironment.application.scenes.isEmpty)
    }

    /// A scene's session closing it closes every native window of it.
    @MainActor
    func testClosingASceneClosesEveryNativeWindowOfIt() async throws {
        stateUIUseApp(AppKitSessionApp())
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        renderer.startForTesting()
        try await StandardEnvironment.application.openWindow(.appKitTestTool)
        renderer.runtime.pump.turn()
        let natives = renderer.windowsForTesting.compactMap(\.window)
        XCTAssertEqual(natives.count, 2)
        let closing = ClosingWatch()
        defer { closing.stop() }

        try await XCTUnwrap(StandardEnvironment.application.scenes.first).close()
        renderer.runtime.pump.turn()

        XCTAssertTrue(renderer.windowsForTesting.isEmpty)
        XCTAssertEqual(renderer.sceneCountForTesting, 0)
        XCTAssertEqual(Set(closing.closed), Set(natives.map(ObjectIdentifier.init)))
    }

    @MainActor
    func testApplicationPersistenceUsesNativeUserDefaults() throws {
        let suite = "StateUIAppKitTests.\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suite))
        PersistentStore.shared.forgetAll()
        defer {
            preferences.removePersistentDomain(forName: suite)
            PersistentStore.shared.forgetAll()
            StandardEnvironment.application.persistentKeys = []
        }
        let key = PersistentKey("theme", of: String.self)
        let state = State(wrappedValue: "light", persistentKey: key)
        StandardEnvironment.application.persistentKeys = [key]
        preferences.set("dark", forKey: key.name)
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            preferences: preferences)

        renderer.hydratePersistentState()
        XCTAssertEqual(state.get(), "dark")

        renderer.savePersistent(HostActCall(
            act: .persistValue,
            arguments: [.name(key.name), .string("graphite")],
            completion: nil))
        XCTAssertEqual(preferences.string(forKey: key.name), "graphite")
    }

    @MainActor
    func testDisplayClockMovesToAnotherWindowWhenItsSourceCloses() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        renderer.applyForTesting(tree(
            scene("1", windows: [window("window 1")]),
            scene("2", windows: [window("window 1")])
        ))
        let first = try XCTUnwrap(renderer.windowsForTesting[0].window)
        let second = try XCTUnwrap(renderer.windowsForTesting[1].window)

        XCTAssertTrue(renderer.frameClockWindowForTesting === first)
        renderer.windowsForTesting[0].windowWillClose(
            Notification(name: NSWindow.willCloseNotification))

        XCTAssertTrue(renderer.frameClockWindowForTesting === second)
    }

    @MainActor
    private func tree(_ scenes: HostPatch...) -> HostPatch {
        var application = HostPatch(id: .manual("application"), type: .application)
        application.children = .arranged(scenes)
        return application
    }

    @MainActor
    private func scene(
        _ id: String,
        windows: [HostPatch],
        eventBase: Int32? = nil
    ) -> HostPatch {
        var scene = HostPatch(id: .manual(id), type: .scene)
        if let eventBase {
            scene.events = .replace([
                .activated: eventBase,
                .deactivated: eventBase + 1,
                .stopped: eventBase + 2,
                .windowClosed: eventBase + 3,
            ])
        }
        scene.children = .arranged(windows)
        return scene
    }

    @MainActor
    private func window(
        _ id: String,
        kind: String? = nil,
        eventBase: Int32? = nil
    ) -> HostPatch {
        var label = HostPatch(id: .manual("label-\(id)"), type: .text)
        label.properties[.text] = .string(id)

        var page = HostPatch(id: .manual("page-\(id)"), type: .page)
        page.children = .arranged([label])

        var window = HostPatch(id: .manual(id), type: .window)
        window.properties[.title] = .string(id)
        if let kind { window.properties[.windowType] = .name(kind) }
        if let eventBase {
            window.events = .replace([
                .created: eventBase,
                .activated: eventBase + 1,
                .deactivated: eventBase + 2,
                .stopped: eventBase + 3,
                .resumed: eventBase + 4,
                .destroying: eventBase + 5,
            ])
        }
        window.children = .arranged([page])
        return window
    }
}

/// The native windows that close while it watches, by identity, in order.
@MainActor
private final class ClosingWatch {
    private(set) var closed: [ObjectIdentifier] = []
    private var token: (any NSObjectProtocol)?

    init() {
        token = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: nil, queue: nil
        ) { [weak self] note in
            guard let window = (note.object as? NSWindow).map(ObjectIdentifier.init) else { return }
            MainActor.assumeIsolated { self?.closed.append(window) }
        }
    }

    func stop() {
        token.map(NotificationCenter.default.removeObserver)
    }
}

private extension WindowType {
    static let appKitTestTool = WindowType("appkit.test.tool")
}

private struct AppKitSessionPage: View {
    let caption: String
    var body: some View { Text(caption) }
}

private struct AppKitSessionScene: Scene {
    var body: some Scene {
        WindowGroup { AppKitSessionPage(caption: "Main") }
        Window(.appKitTestTool) { AppKitSessionPage(caption: "Tool") }
    }
}

private struct AppKitSessionApp: Application {
    var body: some Scene { AppKitSessionScene() }
}

private extension WindowType {
    static let appKitTestEditor = WindowType("appkit.test.editor")
}

/// An application of two scenes: the one with a tool window, and the editors.
private struct AppKitKindsApp: Application {
    var body: some Scene {
        AppKitSessionScene()
        WindowGroup(.appKitTestEditor) { AppKitSessionPage(caption: "Editor") }
    }
}

#endif
