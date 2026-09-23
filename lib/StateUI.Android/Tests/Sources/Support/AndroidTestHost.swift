// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIAndroid
@_spi(Host) import StateUI
@testable import StateUIAndroid
import XCTest

/// The context every test's views are made in: the test APK's application.
@MainActor
enum TestContext {
    static var context: JavaObject!
}

/// The smallest complete application around one page: one scene, one window.
struct OneWindowApplication: Application {
    let page: @Sendable () -> any Page

    var scene: any Scene { OneWindow(content: page) }
}

/// The window of a `OneWindowApplication`, its page built again each time the window is.
struct OneWindow: Window {
    let content: @Sendable () -> any Page

    var page: any Page { content() }
}

extension XCTestCase {
    /// Runs `body` as the main actor's: the runner runs every test on the UI thread.
    func onMainActor(_ body: @MainActor () throws -> Void) rethrows {
        try MainActor.assumeIsolated(body)
    }
}

/// The Java a test reads back: where a view stands, and what a group holds.
@MainActor
enum TestJava {
    static let frameLayout = Java.findClass("android/widget/FrameLayout")
    static let newFrameLayout = Java.method(frameLayout, "<init>", "(Landroid/content/Context;)V")
    static let getLeft = Java.method(JavaAPI.view, "getLeft", "()I")
    static let getTop = Java.method(JavaAPI.view, "getTop", "()I")
    static let getWidth = Java.method(JavaAPI.view, "getWidth", "()I")
    static let getHeight = Java.method(JavaAPI.view, "getHeight", "()I")
    static let getChildCount = Java.method(JavaAPI.viewGroup, "getChildCount", "()I")
    static let getTextSize = Java.method(JavaAPI.textView, "getTextSize", "()F")

    /// An empty root, as an activity's content is.
    static func root() -> JavaObject {
        Java.new(frameLayout, newFrameLayout, .object(TestContext.context.reference))
    }
}

extension AndroidRenderer {
    /// A host running the application whose only window shows what `page` builds, at two pixels a point.
    static func running(_ page: @escaping @Sendable () -> any Page) -> AndroidRenderer {
        stateUIUseApp(OneWindowApplication(page: page))
        let renderer = AndroidRenderer(context: TestContext.context, root: TestJava.root(), density: 2)
        AndroidRenderer.shared = renderer
        renderer.show()
        return renderer
    }

    /// Measures and places the root at `width` by `height` pixels, as a window does.
    func layOut(width: Int32 = 1080, height: Int32 = 1920) {
        Java.call(
            root.reference, JavaAPI.measure,
            .int(ViewConstants.spec(ViewConstants.exactly, width)),
            .int(ViewConstants.spec(ViewConstants.exactly, height)))
        Java.call(root.reference, JavaAPI.layout, .int(0), .int(0), .int(width), .int(height))
    }

    /// Every view of `type` in the mounted tree, depth first.
    func views<Native: AndroidView>(_ type: Native.Type) -> [Native] {
        guard let root = tree.root else { return [] }
        return Self.views(type, in: root)
    }

    private static func views<Native: AndroidView>(_ type: Native.Type, in element: MountedElement) -> [Native] {
        let own = ((element.native as? AndroidElement)?.view as? Native).map { [$0] } ?? []
        return own + element.children.flatMap { views(type, in: $0) }
    }
}

extension AndroidView {
    /// Where the view stands in its parent, and its size, in pixels.
    var frame: (x: Int32, y: Int32, width: Int32, height: Int32) {
        (
            Java.callInt(reference, TestJava.getLeft), Java.callInt(reference, TestJava.getTop),
            Java.callInt(reference, TestJava.getWidth), Java.callInt(reference, TestJava.getHeight)
        )
    }

    /// Clicks the view as the user does: its listener runs.
    func click() {
        _ = Java.jni.CallBooleanMethodA(Java.env, reference, JavaAPI.performClick, nil)
        Java.check("performClick")
    }
}
