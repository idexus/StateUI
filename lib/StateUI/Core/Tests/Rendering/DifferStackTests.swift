// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The walk's stack: a level of the tree costs the differ little of it, so a deep tree fits a small thread's stack - a
// tablet's browser gives a page far less than a desktop does.

import XCTest

@_spi(Host) @testable import StateUI

/// Where on the stack each level's body ran, by its depth.
@MainActor private var marks: [Int: Int] = [:]

/// A composed view holding a stack holding the next level, forty deep.
private struct Level: View {
    let depth: Int

    var body: some View {
        var here = depth
        withUnsafeMutablePointer(to: &here) { marks[depth] = Int(bitPattern: $0) }
        return VStack {
            if depth < 40 { Level(depth: depth + 1) } else { Text("bottom") }
        }
    }
}

@MainActor
final class DifferStackTests: XCTestCase {
    /// A LEVEL OF THE TREE COSTS THE WALK LITTLE STACK: the differ goes down through small frames, the work of each
    /// element done in steps that return before its children are walked. A Gallery in a debug build overflowed a
    /// tablet browser's stack at some fifteen levels, forty kilobytes each.
    func testALevelOfTheTreeCostsTheWalkLittleStack() {
        marks = [:]
        _ = Renders().render(Level(depth: 0).node)
        let perLevel = ((marks[1] ?? 0) - (marks[40] ?? 0)) / 39

        XCTAssertEqual(marks.count, 41, "every level built")
        XCTAssertLessThan(perLevel, 8 * 1024, "bytes of stack a level")
    }
}
