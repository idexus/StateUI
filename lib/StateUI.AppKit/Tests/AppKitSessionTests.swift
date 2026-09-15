// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

final class AppKitSessionTests: XCTestCase {
    @MainActor
    func testApplicationScenesOwnAllOfTheirNativeWindows() {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(
            scene("1", windows: [window("main"), window("fonts 1", kind: "fonts")]),
            scene("2", windows: [window("main")])
        ))

        XCTAssertEqual(renderer.sceneCountForTesting, 2)
        XCTAssertEqual(renderer.windowsForTesting.count, 3)
        XCTAssertEqual(renderer.windowsForTesting.compactMap(\.sceneID), [
            .manual("1"), .manual("1"), .manual("2"),
        ])
        XCTAssertEqual(renderer.windowsForTesting.map(\.isMain), [true, false, true])
        XCTAssertTrue(renderer.windowsForTesting.compactMap(\.window).allSatisfy(NSApp.windows.contains))
    }

    @MainActor
    func testRemovingOneWindowClosesOnlyThatNativeWindow() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        renderer.applyForTesting(tree(
            scene("1", windows: [window("main"), window("fonts 1", kind: "fonts")]),
            scene("2", windows: [window("main")])
        ))
        let main = try XCTUnwrap(renderer.windowsForTesting.first?.window)
        let tool = try XCTUnwrap(renderer.windowsForTesting.dropFirst().first?.window)

        renderer.applyForTesting(tree(
            scene("1", windows: [window("main")]),
            scene("2", windows: [window("main")])
        ))

        XCTAssertEqual(renderer.windowsForTesting.count, 2)
        XCTAssertTrue(renderer.windowsForTesting.first?.window === main)
        XCTAssertFalse(tool.isVisible)
    }

    func testRestorationRecordRoundTripsEverySceneValueKind() throws {
        let record = AppKitRestorationRecord(
            windowIdentifier: "window-B",
            ownerIdentifier: "window-A",
            kind: "document",
            value: "42",
            kept: [
                "enabled": .bool(true),
                "scale": .number(1.25),
                "title": .string("Dusk"),
            ])

        XCTAssertEqual(try AppKitRestorationRecord(data: record.data()), record)
    }

    func testAnOwnedWindowMayBeRestoredBeforeItsSceneMainWindow() {
        let queue = AppKitRestorationQueue()
        let owned = AppKitRestorationRecord(
            windowIdentifier: "tool",
            ownerIdentifier: "main",
            kind: "fonts",
            value: nil)
        let main = AppKitRestorationRecord(windowIdentifier: "main")

        queue.append(owned)
        XCTAssertNil(queue.takeMain())

        queue.append(main)
        XCTAssertEqual(queue.takeMain(), main)
        XCTAssertEqual(queue.takeOwned(by: "main", kind: "fonts", value: nil), owned)
        XCTAssertTrue(queue.isEmpty)
    }

    @MainActor
    func testRestoredNativeWindowsAreClaimedByTheirSceneRegardlessOfArrivalOrder() {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        let ownedRecord = AppKitRestorationRecord(
            windowIdentifier: "restored-tool",
            ownerIdentifier: "restored-main",
            kind: "fonts")
        let mainRecord = AppKitRestorationRecord(windowIdentifier: "restored-main")
        let owned = renderer.acceptRestoredWindow(ownedRecord)
        let main = renderer.acceptRestoredWindow(mainRecord)

        renderer.applyForTesting(tree(
            scene("1", windows: [window("main"), window("fonts 1", kind: "fonts")])
        ))

        XCTAssertEqual(renderer.windowsForTesting.count, 2)
        XCTAssertTrue(renderer.windowsForTesting[0].window === main)
        XCTAssertTrue(renderer.windowsForTesting[1].window === owned)
    }

    @MainActor
    func testARestoredWindowKeepsItsFrameWhenNoGeometryIsRequested() {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        let record = AppKitRestorationRecord(windowIdentifier: UUID().uuidString)
        let restored = renderer.acceptRestoredWindow(record)
        restored.setFrame(
            NSRect(x: 137, y: 211, width: 733, height: 577),
            display: false)
        restored.contentMinSize = NSSize(width: 320, height: 240)
        restored.contentMaxSize = NSSize(width: 1_200, height: 900)
        restored.standardWindowButton(.zoomButton)?.isEnabled = false
        restored.styleMask.remove(.miniaturizable)
        let standing = restored.frame

        renderer.applyForTesting(tree(scene("1", windows: [window("main")])))

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
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var initial = window("main")
        initial.properties[.width] = .number(640)
        initial.properties[.height] = .number(480)
        renderer.applyForTesting(tree(scene("1", windows: [initial])))

        let native = try XCTUnwrap(renderer.windowsForTesting.first?.window)
        native.setContentSize(NSSize(width: 700, height: 550))
        native.setFrameOrigin(NSPoint(x: 137, y: 211))

        var width = HostPatch(id: .manual("main"), type: .window)
        width.properties[.width] = .number(820)
        renderer.applyForTesting(tree(scene("1", windows: [width])))

        var contentSize = native.contentRect(forFrameRect: native.frame).size
        XCTAssertEqual(contentSize.width, 820, accuracy: 0.001)
        XCTAssertEqual(contentSize.height, 550, accuracy: 0.001)
        XCTAssertEqual(native.frame.minX, 137, accuracy: 0.001)

        var relinquishedWidth = HostPatch(id: .manual("main"), type: .window)
        relinquishedWidth.clearedProperties = [.width]
        native.setContentSize(NSSize(width: 910, height: 610))
        renderer.applyForTesting(tree(scene("1", windows: [relinquishedWidth])))

        contentSize = native.contentRect(forFrameRect: native.frame).size
        XCTAssertEqual(contentSize.width, 910, accuracy: 0.001)
        XCTAssertEqual(contentSize.height, 610, accuracy: 0.001)

        let x = native.frame.minX
        let screen = try XCTUnwrap(native.screen ?? NSScreen.main)
        var y = HostPatch(id: .manual("main"), type: .window)
        y.properties[.y] = .number(73)
        renderer.applyForTesting(tree(scene("1", windows: [y])))

        XCTAssertEqual(native.frame.minX, x, accuracy: 0.001)
        XCTAssertEqual(native.frame.maxY, screen.visibleFrame.maxY - 73, accuracy: 0.001)
    }

    @MainActor
    func testWindowMapsAndClearsItsCompleteNativePropertyGroup() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var authored = window("main")
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
        XCTAssertFalse(try XCTUnwrap(native.standardWindowButton(.zoomButton)).isEnabled)
        XCTAssertFalse(native.styleMask.contains(.miniaturizable))
        XCTAssertFalse(
            native.delegate?.windowShouldZoom?(native, toFrame: native.frame) ?? true)

        let standingFrame = native.frame
        var cleared = HostPatch(id: .manual("main"), type: .window)
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
        XCTAssertTrue(try XCTUnwrap(native.standardWindowButton(.zoomButton)).isEnabled)
        XCTAssertTrue(native.styleMask.contains(.miniaturizable))
        XCTAssertTrue(native.delegate?.windowShouldZoom?(native, toFrame: native.frame) ?? true)
    }

    @MainActor
    func testWindowMinimumWinsAContradictoryMaximum() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var authored = window("main")
        authored.properties[.minimumWidth] = .number(640)
        authored.properties[.maximumWidth] = .number(320)
        renderer.applyForTesting(tree(scene("1", windows: [authored])))

        let native = try XCTUnwrap(renderer.windowsForTesting.first?.window)
        XCTAssertEqual(native.contentMinSize.width, 640)
        XCTAssertEqual(native.contentMaxSize.width, 640)
    }

    @MainActor
    func testOwnedWindowMapsAndClearsItsCompleteNativeMetadataGroup() throws {
        var reported: [Int32] = []
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { id, _ in reported.append(id) })
        defer { renderer.closeForTesting() }

        var tool = window("tool", kind: "notes.inspector", eventBase: 300)
        tool.properties[.windowValue] = .string("selection-7")
        tool.properties[.hidesWhenInactive] = .bool(true)
        tool.properties[.floatsOnTop] = .bool(true)
        renderer.applyForTesting(tree(
            scene("1", windows: [window("main"), tool]),
            scene("2", windows: [window("main")])
        ))

        let controller = try XCTUnwrap(renderer.windowsForTesting.dropFirst().first)
        let native = try XCTUnwrap(controller.window)

        XCTAssertFalse(controller.isMain)
        XCTAssertEqual(controller.restorationRecordForTesting.ownerIdentifier,
                       renderer.windowsForTesting.first?.restorationRecordForTesting.windowIdentifier)
        XCTAssertEqual(controller.restorationRecordForTesting.kind, "notes.inspector")
        XCTAssertEqual(controller.restorationRecordForTesting.value, "selection-7")
        XCTAssertTrue(native.isExcludedFromWindowsMenu)
        XCTAssertEqual(native.level, .floating)
        XCTAssertTrue(native.hidesOnDeactivate)

        controller.setSceneActive(true)
        reported.removeAll()
        native.orderFront(nil)
        controller.setSceneActive(false)
        XCTAssertTrue(controller.hiddenBySceneForTesting)
        XCTAssertFalse(native.isVisible)
        XCTAssertEqual(reported, [303])

        var cleared = HostPatch(id: .manual("tool"), type: .window)
        cleared.clearedProperties = [.windowValue, .hidesWhenInactive, .floatsOnTop]
        renderer.applyForTesting(tree(
            scene("1", windows: [window("main"), cleared]),
            scene("2", windows: [window("main")])
        ))

        XCTAssertEqual(controller.restorationRecordForTesting.kind, "notes.inspector")
        XCTAssertNil(controller.restorationRecordForTesting.value)
        XCTAssertFalse(controller.hiddenBySceneForTesting)
        XCTAssertEqual(native.level, .normal)
        XCTAssertFalse(native.hidesOnDeactivate)
        XCTAssertEqual(reported, [303, 304])

        native.orderFront(nil)
        var hiddenAgain = HostPatch(id: .manual("tool"), type: .window)
        hiddenAgain.properties[.hidesWhenInactive] = .bool(true)
        renderer.applyForTesting(tree(
            scene("1", windows: [window("main"), hiddenAgain]),
            scene("2", windows: [window("main")])
        ))

        XCTAssertTrue(controller.hiddenBySceneForTesting)
        XCTAssertFalse(native.isVisible)
        XCTAssertEqual(reported, [303, 304, 303])

        controller.applicationWasHidden()
        renderer.applyForTesting(tree(
            scene("1", windows: [window("main"), cleared]),
            scene("2", windows: [window("main")])
        ))
        XCTAssertFalse(controller.hiddenBySceneForTesting)
        XCTAssertEqual(reported, [303, 304, 303])

        controller.applicationWasUnhidden()
        XCTAssertEqual(reported, [303, 304, 303, 304])
    }

    @MainActor
    func testASceneKeySaveUpdatesTheMainWindowsRestorationRecord() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        renderer.applyForTesting(tree(scene("1", windows: [window("main")])))

        renderer.keepSceneValue(HostActCall(
            act: .persistSceneValue,
            arguments: [.name("1"), .name("shade"), .string("dusk")],
            completion: nil))

        let main = try XCTUnwrap(renderer.windowsForTesting.first)
        XCTAssertEqual(main.restorationRecordForTesting.kept, ["shade": .string("dusk")])
    }

    @MainActor
    func testAWholeOwnedWindowIsOfferedBackToTheRestoredScene() async throws {
        stateUIUseApp(AppKitSessionApp())
        let firstHost = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        firstHost.startForTesting()

        let scene = try XCTUnwrap(Scenes.shared.list.first?.session)
        try await scene.openWindow(.appKitTestTool)
        firstHost.pump()
        XCTAssertEqual(firstHost.windowsForTesting.count, 2)

        let mainRecord = firstHost.windowsForTesting[0].restorationRecordForTesting
        let ownedRecord = firstHost.windowsForTesting[1].restorationRecordForTesting
        firstHost.closeForTesting()

        stateUIUseApp(AppKitSessionApp())
        let restoredHost = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { restoredHost.closeForTesting() }
        let ownedWindow = restoredHost.acceptRestoredWindow(ownedRecord)
        let mainWindow = restoredHost.acceptRestoredWindow(mainRecord)

        restoredHost.startForTesting()

        XCTAssertEqual(restoredHost.windowsForTesting.count, 2)
        XCTAssertTrue(restoredHost.windowsForTesting[0].window === mainWindow)
        XCTAssertTrue(restoredHost.windowsForTesting[1].window === ownedWindow)
    }

    @MainActor
    func testRestoredOwnedWindowOffersItsKindAndValueThroughTheSceneHandler() throws {
        var reported: [(Int32, [HostValue])] = []
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { reported.append(($0, $1)) })
        defer { renderer.closeForTesting() }
        let standing = tree(scene(
            "1",
            windows: [window("main")],
            eventBase: 100))
        renderer.applyForTesting(standing)

        let owner = try XCTUnwrap(
            renderer.windowsForTesting.first?.restorationRecordForTesting.windowIdentifier)
        _ = renderer.acceptRestoredWindow(AppKitRestorationRecord(
            windowIdentifier: "restored-document",
            ownerIdentifier: owner,
            kind: "notes.document",
            value: "selection-7"))
        reported.removeAll()

        renderer.applyForTesting(standing)

        XCTAssertEqual(reported.map(\.0), [104])
        XCTAssertEqual(reported.first?.1, [
            .string("notes.document"),
            .string("selection-7"),
        ])
    }

    @MainActor
    func testPlatformAndStateUICanEachOpenAnotherScene() async throws {
        stateUIUseApp(AppKitSessionApp())
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        renderer.startForTesting()

        XCTAssertEqual(renderer.sceneCountForTesting, 1)

        renderer.openPlatformScene()
        XCTAssertEqual(renderer.sceneCountForTesting, 2)

        try await StandardEnvironment.application.openScene()
        renderer.pump()
        XCTAssertEqual(renderer.sceneCountForTesting, 3)
        XCTAssertEqual(StandardEnvironment.application.scenes.count, 3)
    }

    @MainActor
    func testClosingANativeMainWindowEndsItsSceneAndEveryOwnedWindow() async throws {
        stateUIUseApp(AppKitSessionApp())
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        renderer.startForTesting()
        let scene = try XCTUnwrap(StandardEnvironment.application.scenes.first)
        try await scene.openWindow(.appKitTestTool)
        renderer.pump()
        XCTAssertEqual(renderer.windowsForTesting.count, 2)

        renderer.windowsForTesting[0].windowWillClose(
            Notification(name: NSWindow.willCloseNotification))

        XCTAssertEqual(renderer.sceneCountForTesting, 0)
        XCTAssertTrue(StandardEnvironment.application.scenes.isEmpty)
        XCTAssertTrue(renderer.windowsForTesting.isEmpty)
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
            StandardEnvironment.application.persistentStorage = .preferences
        }
        let key = PersistentKey("theme", of: String.self)
        let state = State(wrappedValue: "light", persistentKey: key)
        StandardEnvironment.application.persistentStorage = .preferences
        StandardEnvironment.application.persistentKeys = [key]
        preferences.set("dark", forKey: key.name)
        let renderer = AppKitRenderer(
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
    func testFocusMovesBetweenScenesButNotBetweenWindowsOfOneScene() {
        var reported: [(Int32, [HostValue])] = []
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { reported.append(($0, $1)) })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(
            scene("1", windows: [
                window("main", eventBase: 200),
                window("fonts 1", kind: "fonts", eventBase: 300),
            ], eventBase: 100),
            scene("2", windows: [window("main", eventBase: 500)], eventBase: 400)
        ))
        reported.removeAll()

        let first = renderer.windowsForTesting[0]
        let tool = renderer.windowsForTesting[1]
        let secondScene = renderer.windowsForTesting[2]
        first.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification))
        first.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification))
        tool.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification))

        XCTAssertEqual(reported.map(\.0), [201, 100, 202, 301])

        reported.removeAll()
        secondScene.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification))
        XCTAssertEqual(reported.map(\.0), [501, 101, 400])
    }

    @MainActor
    func testHideAndUnhideMoveApplicationSceneAndWindowPhasesOnce() {
        var reported: [(Int32, [HostValue])] = []
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { reported.append(($0, $1)) })
        defer { renderer.closeForTesting() }
        renderer.applyForTesting(tree(scene("1", windows: [
            window("main", eventBase: 200),
            window("fonts 1", kind: "fonts", eventBase: 300),
        ], eventBase: 100)))
        reported.removeAll()

        renderer.applicationWasHidden()
        renderer.applicationWasHidden()
        XCTAssertEqual(StandardEnvironment.application.phase, .background)
        XCTAssertEqual(reported.map(\.0), [102, 203, 303])

        reported.removeAll()
        renderer.applicationWasUnhidden()
        renderer.applicationWasUnhidden()
        XCTAssertEqual(StandardEnvironment.application.phase, .inactive)
        XCTAssertEqual(reported.map(\.0), [101, 204, 304])
    }

    @MainActor
    func testAMiniaturizedSceneStaysStoppedWhileTheApplicationHideCauseComesAndGoes()
        async throws
    {
        stateUIUseApp(AppKitSessionApp())
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        renderer.startForTesting()

        let scene = try XCTUnwrap(StandardEnvironment.application.scenes.first)
        let window = try XCTUnwrap(scene.windows.first)
        let main = try XCTUnwrap(renderer.windowsForTesting.first)
        try await scene.openWindow(.appKitTestTool)
        renderer.pump()
        let tool = try XCTUnwrap(renderer.windowsForTesting.last)

        main.windowDidMiniaturize(Notification(name: NSWindow.didMiniaturizeNotification))
        XCTAssertEqual(scene.phase, .background)
        XCTAssertEqual(window.phase, .stopped)

        tool.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification))
        XCTAssertEqual(scene.phase, .active)

        renderer.applicationWasHidden()
        renderer.applicationWasUnhidden()
        XCTAssertEqual(scene.phase, .background)
        XCTAssertEqual(window.phase, .stopped)

        main.windowDidDeminiaturize(Notification(name: NSWindow.didDeminiaturizeNotification))
        XCTAssertEqual(scene.phase, .inactive)
        XCTAssertEqual(window.phase, .resumed)
    }

    @MainActor
    func testClosingAnOwnedWindowReportsItsWindowThenItsSceneKey() {
        var reported: [(Int32, [HostValue])] = []
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { reported.append(($0, $1)) })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(scene("1", windows: [
            window("main", eventBase: 200),
            window("fonts 1", kind: "fonts", eventBase: 300),
        ], eventBase: 100)))
        reported.removeAll()

        renderer.windowsForTesting[1].windowWillClose(
            Notification(name: NSWindow.willCloseNotification))

        XCTAssertEqual(reported.map(\.0), [305, 105])
        XCTAssertEqual(reported.last?.1, [.string("fonts 1")])
    }

    @MainActor
    func testClosingAMainWindowReportsItsWindowThenDestroysItsScene() {
        var reported: [(Int32, [HostValue])] = []
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { reported.append(($0, $1)) })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(scene(
            "1",
            windows: [window("main", eventBase: 200)],
            eventBase: 100)))
        reported.removeAll()

        renderer.windowsForTesting[0].windowWillClose(
            Notification(name: NSWindow.willCloseNotification))

        XCTAssertEqual(reported.map(\.0), [205, 103])
    }

    @MainActor
    func testTreeRemovalClosesAWindowWithoutReportingNativeCloseBack() {
        var reported: [(Int32, [HostValue])] = []
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { reported.append(($0, $1)) })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(scene("1", windows: [
            window("main", eventBase: 200),
            window("fonts 1", kind: "fonts", eventBase: 300),
        ], eventBase: 100)))
        reported.removeAll()

        renderer.applyForTesting(tree(scene(
            "1",
            windows: [window("main", eventBase: 200)],
            eventBase: 100)))

        XCTAssertTrue(reported.isEmpty)
    }

    @MainActor
    func testDisplayClockMovesToAnotherWindowWhenItsSourceCloses() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        renderer.applyForTesting(tree(
            scene("1", windows: [window("main")]),
            scene("2", windows: [window("main")])
        ))
        let first = try XCTUnwrap(renderer.windowsForTesting[0].window)
        let second = try XCTUnwrap(renderer.windowsForTesting[1].window)

        XCTAssertTrue(renderer.displayWindowForTesting === first)
        renderer.windowsForTesting[0].windowWillClose(
            Notification(name: NSWindow.willCloseNotification))

        XCTAssertTrue(renderer.displayWindowForTesting === second)
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
                .destroying: eventBase + 3,
                .windowRestored: eventBase + 4,
                .windowClosed: eventBase + 5,
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
        var label = HostPatch(id: .manual("label-\(id)"), type: .label)
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

private extension WindowType {
    static let appKitTestTool = WindowType("appkit.test.tool")
}

private struct AppKitSessionPage: ContentView {
    let caption: String
    var content: any View { Label(caption) }
}

private struct AppKitSessionMainWindow: Window {
    var page: any Page { AppKitSessionPage(caption: "Main") }
}

private struct AppKitSessionToolWindow: Window {
    var page: any Page { AppKitSessionPage(caption: "Tool") }
}

private struct AppKitSessionScene: Scene {
    var windows: Windows {
        Windows {
            WindowGroup(.appKitTestTool) { AppKitSessionToolWindow() }
        } main: {
            AppKitSessionMainWindow()
        }
    }
}

private struct AppKitSessionApp: Application {
    var scene: any Scene { AppKitSessionScene() }
}

#endif
