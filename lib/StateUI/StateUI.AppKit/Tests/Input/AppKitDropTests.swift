// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import XCTest

/// What the words dropped on a target landed as: its number, and the words.
@MainActor
private final class Landed {
    var drops: [String] = []
}

/// A target taking words, which Swap replaces with a new one in its place.
private struct SwappedTarget: View {
    let landed: Landed
    @State private var number = 1

    var body: some View {
        VStack {
            Text("target \(number)")
                .onDropped { [number, landed] words in landed.drops.append("\(number): \(words)") }
                .id(number)
            Button("Swap")
                .onClicked { number += 1 }
        }
    }
}

/// The drags a window takes as AppKit tells them: a view taking drops is found under the drag wherever it stands now.
@MainActor
final class AppKitDropTests: XCTestCase {
    /// A target replaced while a drag is over it: the drag moving over the new one finds it, and the words let go
    /// land in it.
    func testATargetComingUnderADragTakesItsDrop() throws {
        let landed = Landed()
        let renderer = AppKitRenderer.running { SwappedTarget(landed: landed) }
        defer { renderer.finish() }
        let target = try XCTUnwrap(renderer.nativeViews(AppKitTextView.self).first)
        let root = try XCTUnwrap(target.window?.contentView as? AppKitWindowContentView)
        let drops = try XCTUnwrap(root.drops)
        let carried = AppKitDrops.Carried(words: "words")
        root.layoutSubtreeIfNeeded()
        let middle = target.convert(NSPoint(x: target.bounds.midX, y: target.bounds.midY), to: nil)
        XCTAssertEqual(drops.entered(at: middle, carrying: carried, in: root), .copy, "the drag is over the target")

        renderer.nativeViews(AppKitButtonView.self).first?.clickForTesting()
        renderer.runtime.pump.turn()
        root.layoutSubtreeIfNeeded()

        XCTAssertEqual(drops.moved(to: middle, carrying: carried, in: root), .copy, "the drag is over the new target")
        XCTAssertTrue(drops.dropped(carried))
        XCTAssertEqual(landed.drops, ["2: words"])
    }
}
#endif
