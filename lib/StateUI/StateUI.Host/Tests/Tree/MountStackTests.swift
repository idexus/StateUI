// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The mount's stack: a level of the tree costs the host layer little of it as it makes and applies the elements, so a
// deep tree fits a small thread's stack - a tablet's browser gives a page far less than a desktop does.

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// Where on the stack each element's native half was made, by how deep it stands.
@MainActor private var marks: [Int: Int] = [:]

/// A composed view holding a stack holding the next level, forty deep.
private struct Level: View {
    let depth: Int

    var body: some View {
        VStack {
            if depth < 40 { Level(depth: depth + 1) } else { Text("bottom") }
        }
    }
}

private struct DeepApplication: Application {
    var body: some Scene { WindowGroup { Level(depth: 0) } }
}

@MainActor
final class MountStackTests: XCTestCase {
    /// A LEVEL OF THE TREE COSTS THE MOUNT LITTLE STACK: the host layer goes down through small frames, an element's
    /// own work done in steps that return before its children are made. A Gallery in a debug build overflowed a
    /// tablet browser's stack there once the differ no longer did.
    func testALevelOfTheTreeCostsTheMountLittleStack() {
        marks = [:]
        stateUIUseApp(DeepApplication())
        let runtime = HostRuntime(clock: StillClock(), reducesMotion: { false }, makeNative: { element in
            var depth = 0
            var above = element.parent
            while let next = above {
                depth += 1
                above = next.parent
            }
            var here = depth
            marks[depth] = withUnsafeMutablePointer(to: &here) { Int(bitPattern: $0) }
            return NoView()
        }, log: { _ in })
        runtime.connectWindow()
        runtime.pump.turn()

        let deepest = marks.keys.max() ?? 0
        let (from, to) = (deepest - 35, deepest - 5)
        let perLevel = ((marks[from] ?? 0) - (marks[to] ?? 0)) / (to - from)

        XCTAssertGreaterThan(deepest, 40, "every level made")
        XCTAssertLessThan(perLevel, 8 * 1024, "bytes of stack a level")
    }
}

