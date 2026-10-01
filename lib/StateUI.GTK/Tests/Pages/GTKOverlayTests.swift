// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
import StateUIConformance
import XCTest

/// A page filled by a button, declaring a notice over its window while a state says so.
private struct OverlaidPage: ContentView {
    let notice: State<Bool>

    var content: some View {
        let notice = notice
        return Button("Beneath")
            .horizontalAlignment(.fill)
            .verticalAlignment(.fill)
            .overlays {
                if notice.wrappedValue {
                    Label("Offline").horizontalAlignment(.center).verticalAlignment(.start)
                }
            }
    }
}

/// A page filled by a button, which tells its scene.
private struct ScenePage: ContentView {
    let scenes: Received<SceneSession>
    @Environment private var scene: SceneSession

    var content: some View {
        let (scenes, scene) = (self.scenes, self.scene)
        return Button("Beneath")
            .horizontalAlignment(.fill)
            .verticalAlignment(.fill)
            .onCreated { scenes.values.append(scene) }
    }
}

final class GTKOverlayTests: XCTestCase {
    /// An overlay the page declares stands over it where its alignments put it; a click beside it reaches the page,
    /// and the tree taking it away takes it off the window.
    func testAnOverlayThePageDeclaresStandsOverThePage() throws {
        try onUIThread {
            let notice = State(wrappedValue: false)
            let host = GTKRenderer.running { OverlaidPage(notice: notice) }
            let beneath = try XCTUnwrap(host.views(GTKButtonView.self).first)
            let offline = { host.views(GTKLabelView.self).first { $0.text == "Offline" } }
            XCTAssertNil(offline())

            notice.wrappedValue = true
            host.settle { offline() != nil }
            host.layOut()
            let words = try XCTUnwrap(offline())
            let size = beneath.frame
            XCTAssertEqual(words.frame.y, 0, "at the top, where its alignment puts it")
            XCTAssertTrue(words.reaches(words.frame.width / 2, words.frame.height / 2))
            XCTAssertTrue(beneath.reaches(size.width / 2, size.height / 2), "a click beside it reaches the page")

            notice.wrappedValue = false
            host.settle { offline() == nil }
            XCTAssertNil(offline())
        }
    }

    /// The window's overlay - the inspector docked in it - stands over its page, and a click beside what it holds
    /// goes on to the page; closed, it is gone.
    func testTheWindowsOverlayStandsOverItsPageLettingAClickBesideItThrough() throws {
        try onUIThread {
            let scenes = Received<SceneSession>()
            let host = GTKRenderer.running { ScenePage(scenes: scenes) }
            let window = try XCTUnwrap(host.window)
            let scene = try XCTUnwrap(scenes.values.last)
            defer { Inspector.close(in: scene) }
            let beneath = try XCTUnwrap(host.views(GTKButtonView.self).first)
            let size = beneath.frame
            XCTAssertTrue(beneath.reaches(size.width / 2, size.height - 20), "nothing over the page yet")

            Inspector.open(in: scene)
            host.settle { !window.overlays.isEmpty }
            let overlay = try XCTUnwrap((host.runtime.tree.root?.first(type: .overlay)?.native as? GTKElement)?.view)
            XCTAssertTrue(window.overlays.elementsEqual([overlay], by: ===))
            host.layOut()
            XCTAssertFalse(beneath.reaches(size.width / 2, size.height - 20), "the folded inspector along the bottom")
            let strip = beneath.point(size.width / 2, size.height - 20, in: overlay)
            XCTAssertTrue(overlay.reaches(strip.x, strip.y), "the overlay spans the window, its header bars too")
            XCTAssertTrue(beneath.reaches(size.width / 2, 20), "a click beside it reaches the page")

            Inspector.close(in: scene)
            host.settle { window.overlays.isEmpty }
            XCTAssertTrue(window.overlays.isEmpty)
            XCTAssertTrue(beneath.reaches(size.width / 2, size.height - 20), "taken out of the window")
        }
    }
}

private extension GTKView {
    /// The view's own point `x`, `y` in `other`'s coordinates.
    func point(_ x: Double, _ y: Double, in other: GTKView) -> (x: Double, y: Double) {
        var from = graphene_point_t(x: Float(x), y: Float(y))
        var to = graphene_point_t()
        _ = gtk_widget_compute_point(widget, other.widget, &from, &to)
        return (Double(to.x), Double(to.y))
    }

    /// Whether a click at the view's own point `x`, `y` reaches it or what stands in it.
    func reaches(_ x: Double, _ y: Double) -> Bool {
        guard let root = gtk_widget_get_root(widget).map(GTKWidget.init) else { return false }
        var from = graphene_point_t(x: Float(x), y: Float(y))
        var at = graphene_point_t()
        guard gtk_widget_compute_point(widget, root, &from, &at) != 0,
              let picked = gtk_widget_pick(root, Double(at.x), Double(at.y), GTK_PICK_DEFAULT)
        else { return false }
        return picked == widget || gtk_widget_is_ancestor(picked, widget) != 0
    }
}
