// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

/// A message means something only against the tree it was computed from: one
/// about a tree the host is not holding is refused, and recovered with a
/// complete render.
final class AppKitPatchIntakeTests: XCTestCase {
    private func stack(_ children: [String]) -> HostPatch {
        var stack = HostPatch(id: .manual("stack"), type: .vStack)
        stack.children = .arranged(children.map { HostPatch(id: .manual($0), type: .colorBox) })
        return stack
    }

    /// A sparse message naming a child the tree does not hold is drift - a new
    /// child always arrives in an arranged list - and nothing is mounted from
    /// its partial description.
    @MainActor
    func testASparseMessageNamingAChildTheTreeDoesNotHoldIsRefused() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        renderer.applyForTesting(stack(["a", "b"]))
        XCTAssertGreaterThan(renderer.baselineForTesting, 0, "a message applied whole is claimed")

        var sparse = HostPatch(id: .manual("stack"), type: .vStack)
        sparse.children = .changed([HostPatch(id: .manual("stranger"), type: .colorBox)])
        renderer.applyForTesting(sparse)

        XCTAssertNil(
            renderer.viewForTesting(id: .manual("stranger")),
            "nothing is mounted from a drifted patch")
        XCTAssertNotNil(renderer.viewForTesting(id: .manual("a")))
        XCTAssertEqual(renderer.baselineForTesting, 0, "a refused message claims no generation")
        XCTAssertTrue(renderer.driftForTesting?.contains("stranger") ?? false)
    }

    /// A message about an element the host lost is refused and asked for again
    /// whole: the element comes back as the tree describes it, not as the
    /// sparse patch alone would have made it.
    @MainActor
    func testADriftedMessageIsRecoveredWithACompleteRender() throws {
        let renderer = AppKitRenderer.running { Counter() }
        defer { renderer.closeForTesting() }
        let label = try XCTUnwrap(renderer.nativeViews(AppKitLabelView.self).first)
        XCTAssertEqual(label.textForTesting.string, "0")

        renderer.forgetForTesting(label)
        try XCTUnwrap(renderer.nativeViews(AppKitButtonView.self).first).clickForTesting()

        let recovered = try XCTUnwrap(renderer.nativeViews(AppKitLabelView.self).first)
        let font = recovered.textForTesting.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        XCTAssertEqual(recovered.textForTesting.string, "1")
        XCTAssertEqual(font?.pointSize, 24, "described whole, not from the sparse patch")
        XCTAssertNotNil(renderer.driftForTesting)
        XCTAssertGreaterThan(renderer.baselineForTesting, 0, "the complete render is claimed")
    }
}

/// A count in a label, and a button that adds one.
private struct Counter: ContentView {
    @State private var count = 0

    var content: any View {
        VStack {
            Label("\(count)").fontSize(24)
            Button("Add").onClicked { count += 1 }
        }
    }
}
#endif
