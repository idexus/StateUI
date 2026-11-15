// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
@testable import StateUIGTKDriver
@_spi(Host) import StateUIConformance
import XCTest

/// A page whose note a click takes away.
struct NotePage: View {
    @State private var shown = true

    var body: some View {
        VStack {
            if shown {
                Text("note")
            }
            Button("Hide")
                .onClicked { shown = false }
        }
    }
}

@MainActor
final class GTKLeaveTests: XCTestCase {
    /// An element that leaves the tree lets go of its widget: Swift holds one view fewer, and the panel one child.
    func testAViewIsLetGoOfWhenItsElementLeaves() throws {
        try onUIThread {
            let host = GTKRenderer.running { NotePage() }
            let before = GTKView.liveCount
            XCTAssertEqual(host.views(GTKTextView.self).map(\.text), ["note"])
            let stack = try XCTUnwrap(host.views(GTKStackView.self).first)

            try XCTUnwrap(host.views(GTKButtonView.self).first).click()
            // A view's deinit is MainActor's, and runs in the turn after the one it left in.
            _ = host.runtime.core.runJobs()

            XCTAssertEqual(host.views(GTKTextView.self).count, 0)
            XCTAssertEqual(GTKView.liveCount, before - 1, "the label's view outlived its element")
            XCTAssertEqual(Self.children(of: stack.widget), 1, "the panel still holds the label's widget")
        }
    }

    /// Every element shown and taken away twice leaves the host holding as many views as the first time.
    func testEveryElementsViewIsLetGoOfEachTimeItLeaves() throws {
        try onUIThread {
            XCTAssertEqual(try Leaving.outlived(on: GTKDriver()), [])
        }
    }

    /// A view that leaves takes its drags off at once: a drop landing before its view is let go reaches nothing.
    func testAViewThatLeavesTakesItsDragsOff() throws {
        try onUIThread {
            let shown = State(wrappedValue: true)
            let host = GTKRenderer.running {
                VStack {
                    if shown.wrappedValue {
                        Text("Target").onDropped { _ in }
                    }
                }
            }
            let target = try XCTUnwrap(host.views(GTKTextView.self).first)
            XCTAssertNotNil(target.dragAndDrop)

            shown.wrappedValue = false
            host.settle { host.views(GTKTextView.self).isEmpty }
            XCTAssertNil(target.dragAndDrop, "its drop target outlived its element")
        }
    }

    /// A page the stack takes away - popped by the program, replaced, or taken away by the user's back - is let go
    /// of: its navigation page, and every widget in it with it.
    func testAPageTheStackTakesAwayIsLetGoOf() throws {
        try onUIThread {
            let path = State(wrappedValue: [Int]())
            let host = GTKRenderer.running {
                NavigationStack(path.projectedValue) {
                    Text("Root")
                } destination: { number in Text("Page \(number)") }
            }
            let navigation = try XCTUnwrap(host.views(GTKNavigationView.self).first)

            for (pushed, after) in [([1], [Int]()), ([1], [2]), ([3], nil)] {
                path.wrappedValue = pushed
                host.settle { navigation.stack.count == 2 && navigation.titles.count == 2 }
                let watched = UnsafeMutablePointer<gpointer?>.allocate(capacity: 1)
                defer { watched.deallocate() }
                let page = try XCTUnwrap(navigation.stack.last?.page)
                watched.pointee = UnsafeMutableRawPointer(page)
                g_object_add_weak_pointer(page.of(GObject.self), watched)

                if let after { path.wrappedValue = after } else { XCTAssertTrue(navigation.popByUser()) }
                host.settle { watched.pointee == nil }
                XCTAssertNil(watched.pointee, "the page outlived its going: \(after.map { "\($0)" } ?? "the user's back")")
                if let page = watched.pointee { g_object_remove_weak_pointer(page.assumingMemoryBound(to: GObject.self), watched) }
                path.wrappedValue = []
                host.settle { navigation.stack.count == 1 }
            }
        }
    }

    /// A page the focus came to as the path replaced the page holding it is let go of as the path replaces it in
    /// turn, and the focus comes to the page replacing it, as a push or a pop brings it.
    func testAPageReplacedWithTheFocusInItIsLetGoOf() throws {
        try onUIThread {
            let path = State(wrappedValue: [1, 2])
            let host = GTKRenderer.running {
                NavigationStack(path.projectedValue) {
                    Text("Root")
                } destination: { number in VStack { Text("Page \(number)"); Button("Go \(number)").onClicked {} } }
            }
            let navigation = try XCTUnwrap(host.views(GTKNavigationView.self).first)
            host.settle { navigation.stack.count == 3 }
            let first = try XCTUnwrap(navigation.stack.last?.page)
            let root = try XCTUnwrap(gtk_widget_get_root(first))
            let button = try XCTUnwrap(host.views(GTKButtonView.self).first { gtk_widget_is_ancestor($0.widget, first) != 0 })
            gtk_widget_grab_focus(button.widget)
            @MainActor func replace(by next: Int) {
                let top = navigation.stack.last?.page
                path.wrappedValue = [1, next]
                host.settle { navigation.stack.last?.page != top }
                for _ in 0..<20 { host.step() }
                GTKTestHost.pump(0.5)
            }
            for next in [3, 2, 3] {
                replace(by: next)
                let page = try XCTUnwrap(navigation.stack.last?.page)
                let focus = gtk_root_get_focus(root)
                XCTAssertTrue(focus.map { gtk_widget_is_ancestor($0, page) != 0 } ?? false, "the focus came to page \(next)")
                let watched = UnsafeMutablePointer<gpointer?>.allocate(capacity: 1)
                defer { watched.deallocate() }
                watched.pointee = UnsafeMutableRawPointer(page)
                g_object_add_weak_pointer(page.of(GObject.self), watched)
                replace(by: next == 3 ? 2 : 3)
                XCTAssertNil(watched.pointee, "page \(next), holding the focus, outlived its replacing")
                if let page = watched.pointee { g_object_remove_weak_pointer(page.assumingMemoryBound(to: GObject.self), watched) }
            }
        }
    }

    /// Pages pushed, replaced and popped with their transitions asked for leave the host holding the views it held
    /// before, round after round: counted, not read from the process's memory. A test's window gets no frames, so
    /// libadwaita runs no transition here; the Gallery walks them.
    func testPagesComingAndGoingOnTheirTransitionsLeaveNothingHeld() throws {
        try onUIThread {
            let path = State(wrappedValue: [Int]())
            let host = GTKRenderer.running {
                NavigationStack(path.projectedValue) {
                    Text("Root")
                } destination: { number in VStack { Text("Page \(number)"); Button("Go").onClicked {} } }
            }
            let navigation = try XCTUnwrap(host.views(GTKNavigationView.self).first)
            _ = host.runtime.core.runJobs()
            let before = GTKView.liveCount

            for round in 0..<3 {
                path.wrappedValue = [round, round + 10]
                host.settle { navigation.stack.count == 3 }
                path.wrappedValue = [round + 20]
                host.settle { navigation.stack.count == 2 }
                path.wrappedValue = []
                host.settle { navigation.stack.count == 1 }
                host.settle {
                    _ = host.runtime.core.runJobs()
                    return GTKView.liveCount == before
                }
                XCTAssertEqual(GTKView.liveCount, before, "views outlived round \(round)")
            }
        }
    }

    private static func children(of widget: GTKWidget) -> Int {
        var count = 0
        var child = gtk_widget_get_first_child(widget)
        while let each = child {
            count += 1
            child = gtk_widget_get_next_sibling(each)
        }
        return count
    }
}
