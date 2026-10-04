// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
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

    /// A message about an element the host lost is refused and asked for again
    /// whole: the element comes back as the tree describes it, not as the
    /// sparse patch alone would have made it.
    @MainActor
    func testADriftedMessageIsRecoveredWithACompleteRender() throws {
        let renderer = AppKitRenderer.running { Counter() }
        defer { renderer.closeForTesting() }
        let label = try XCTUnwrap(renderer.nativeViews(AppKitTextView.self).first)
        XCTAssertEqual(label.textForTesting.string, "0")

        renderer.forgetForTesting(label)
        try XCTUnwrap(renderer.nativeViews(AppKitButtonView.self).first).clickForTesting()

        let recovered = try XCTUnwrap(renderer.nativeViews(AppKitTextView.self).first)
        let font = recovered.textForTesting.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        XCTAssertEqual(recovered.textForTesting.string, "1")
        XCTAssertEqual(font?.pointSize, 24, "described whole, not from the sparse patch")
        XCTAssertNotNil(renderer.driftForTesting)
        XCTAssertGreaterThan(renderer.baselineForTesting, 0, "the complete render is claimed")
    }
}

/// A count in a label, and a button that adds one.
private struct Counter: View {
    @State private var count = 0

    var body: some View {
        VStack {
            Text("\(count)").fontSize(24)
            Button("Add").onClicked { count += 1 }
        }
    }
}
#endif
