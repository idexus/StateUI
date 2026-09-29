// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import StateUIConformance
import XCTest

/// The smallest complete application around one piece of content: one
/// scene, one window, one content page. Tests hand it to the renderer so the
/// content mounts where an application mounts it.
func tree(_ content: HostPatch) -> HostPatch {
    var page = HostPatch(id: .manual("page"), type: .page)
    page.children = .arranged([content])
    var window = HostPatch(id: .manual("window"), type: .window)
    window.children = .arranged([page])
    var scene = HostPatch(id: .manual("scene"), type: .scene)
    scene.children = .arranged([window])
    var application = HostPatch(id: .manual("application"), type: .application)
    application.children = .arranged([scene])
    return application
}

/// A later patch of the same application in which only `content` changed.
func changedTree(_ content: HostPatch) -> HostPatch {
    var page = HostPatch(id: .manual("page"), type: .page)
    page.children = .changed([content])
    var window = HostPatch(id: .manual("window"), type: .window)
    window.children = .changed([page])
    var scene = HostPatch(id: .manual("scene"), type: .scene)
    scene.children = .changed([window])
    var application = HostPatch(id: .manual("application"), type: .application)
    application.children = .changed([scene])
    return application
}

extension AppKitRenderer {
    /// A host running the application whose only window shows what `page`
    /// builds, registered and started as an application is: what the page
    /// says in Swift reaches the native views through the host, and what a
    /// native view reports reaches the page's handlers.
    ///
    /// `page` is `@Sendable`, which keeps it and every handler written in it
    /// off the test's main actor: a handler runs on the executor that
    /// dispatches its event, as an application's does, and has run by the
    /// time the native control's report returns. A handler isolated to the
    /// main actor never runs when its event is dispatched.
    @MainActor
    static func running(_ page: @escaping @Sendable () -> any Page) -> AppKitRenderer {
        stateUIUseApp(OneWindowApplication(page: page))
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        renderer.startForTesting()
        return renderer
    }

    /// Every native view of `type` in the first window, in the order a
    /// depth-first walk meets them - a stack's children in source order.
    @MainActor
    func nativeViews<Native: NSView>(_ type: Native.Type) -> [Native] {
        guard let content = windowsForTesting.first?.window?.contentView else { return [] }
        return Self.views(type, in: content)
    }

    @MainActor
    private static func views<Native: NSView>(_ type: Native.Type, in view: NSView) -> [Native] {
        let own = (view as? Native).map { [$0] } ?? []
        return own + view.subviews.flatMap { views(type, in: $0) }
    }
}

/// Presses Return in `field` as a user does: the field takes the focus,
/// and its editor receives the newline that ends the editing.
@MainActor
func pressReturn(in field: NSTextField) throws {
    let window = try XCTUnwrap(field.window)
    XCTAssertTrue(window.makeFirstResponder(field))
    let editor = try XCTUnwrap(field.currentEditor() as? NSTextView)
    editor.insertNewline(nil)
}

/// Whether the editor a user types into `field` with checks spelling,
/// read once a keystroke has begun the editing.
@MainActor
func editorChecksSpelling(whileTypingIn field: NSTextField) throws -> Bool {
    let window = try XCTUnwrap(field.window)
    XCTAssertTrue(window.makeFirstResponder(field))
    let editor = try XCTUnwrap(field.currentEditor() as? NSTextView)
    editor.insertText("!", replacementRange: editor.selectedRange())
    return editor.isContinuousSpellCheckingEnabled
}

/// What `view` draws, as a bitmap of its bounds - `width` pixels wide when
/// given, so a drawing that reaches past the view's edge would show.
@MainActor
func bitmap(of view: NSView, width: Int? = nil) throws -> NSBitmapImageRep {
    let image = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width ?? Int(view.bounds.width),
        pixelsHigh: Int(view.bounds.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0)
    let bitmap = try XCTUnwrap(image)
    let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap))
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    view.draw(view.bounds)
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

/// The first column of `view` holding ink, drawn WITH everything under it.
///
/// `bitmap(of:)` above asks what one view's own `draw(_:)` puts down. This asks
/// what the whole subtree shows, which is the only way to see where a native
/// control beneath a StateUI view placed its words: a stored alignment says
/// what the view was told, never where the glyphs landed.
@MainActor
func firstInkColumn(of view: NSView) throws -> Int {
    let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
    view.cacheDisplay(in: view.bounds, to: bitmap)

    for x in 0..<bitmap.pixelsWide {
        for y in 0..<bitmap.pixelsHigh {
            guard let pixel = bitmap.colorAt(x: x, y: y) else { continue }

            if pixel.alphaComponent > 0.1 { return x }
        }
    }

    return bitmap.pixelsWide
}

/// Where `view` puts ink that `holds` says is its own, drawn WITH everything under it, in points from its top
/// left; nil where it draws none - where a placeholder's glyphs landed, told apart by their colour.
@MainActor
func inkBounds(of view: NSView, where holds: (NSColor) -> Bool) throws -> NSRect? {
    let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
    view.cacheDisplay(in: view.bounds, to: bitmap)

    var (left, top, right, bottom) = (Int.max, Int.max, -1, -1)
    for x in 0..<bitmap.pixelsWide {
        for y in 0..<bitmap.pixelsHigh {
            guard let pixel = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB), holds(pixel) else { continue }
            (left, top, right, bottom) = (min(left, x), min(top, y), max(right, x), max(bottom, y))
        }
    }
    guard right >= 0 else { return nil }

    let scale = CGFloat(bitmap.pixelsWide) / max(view.bounds.width, 1)
    return NSRect(
        x: CGFloat(left) / scale, y: CGFloat(top) / scale,
        width: CGFloat(right - left + 1) / scale, height: CGFloat(bottom - top + 1) / scale)
}

/// Whether `pixel` is plainly red: a red placeholder's glyphs, not their blended edge.
func isRed(_ pixel: NSColor) -> Bool {
    pixel.redComponent > 0.8 && pixel.greenComponent < 0.35 && pixel.blueComponent < 0.35
}

/// The first row of `view` holding ink, drawn WITH everything under it.
///
/// The other half of `firstInkColumn(of:)`, for the question of where words sit
/// down the height they were given.
@MainActor
func firstInkRow(of view: NSView) throws -> Int {
    let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
    view.cacheDisplay(in: view.bounds, to: bitmap)

    for y in 0..<bitmap.pixelsHigh {
        for x in 0..<bitmap.pixelsWide {
            guard let pixel = bitmap.colorAt(x: x, y: y) else { continue }

            if pixel.alphaComponent > 0.1 { return y }
        }
    }

    return bitmap.pixelsHigh
}
#endif
