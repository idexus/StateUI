// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// Where the focus is, told to the elements following it by one pass every host whose toolkit tells only that the
/// focus moved shares.
@MainActor
final class FocusReportTests: XCTestCase {
    /// An element following its focus is told as the focus comes and as it goes, its last word kept, so a pass
    /// finding it where it was tells nothing; one following nothing is not asked.
    func testTheFocusIsToldOnceWhereItMoved() throws {
        let runtime = HostRuntime.still()
        var name = HostPatch(id: .manual("name"), type: .text)
        name.events = .replace([.isFocusedChanged: 7])
        var stack = HostPatch(id: .manual("stack"), type: .vStack)
        stack.children = .arranged([name, HostPatch(id: .manual("note"), type: .text)])
        runtime.tree.apply(stack, complete: true)
        let root = try XCTUnwrap(runtime.tree.root)
        let following = try XCTUnwrap(root.first(id: .manual("name")))
        var holder: ElementID? = .manual("name")
        var asked: [ElementID] = []
        let pass = {
            root.reportFocus(in: runtime) { element in
                asked.append(element.id)
                return element.id == holder
            }
        }

        pass()
        XCTAssertTrue(following.reportedFocus, "told it came")
        pass()
        XCTAssertTrue(following.reportedFocus)
        holder = nil
        pass()
        XCTAssertFalse(following.reportedFocus, "told it went")
        XCTAssertEqual(Set(asked), [.manual("name")], "what follows nothing is not asked")
    }
}
