// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Where every view stands, as the frame it reports says: the size the tree states, bounded as the tree bounds it,
/// its margin, and its alignment in its parent's room - StateUI's arithmetic, the same on every host - each case
/// made for every element wearing the tier.
@_spi(Host) public enum Layout: ConformanceFamily {
    public static let name = "Layout"

    public static var cases: [ConformanceCase] {
        var cases: [ConformanceCase] = []
        for element in Specimens.wearing(ViewContract.self) {
            cases.append(sized(element))
            cases.append(bounded(element))
            cases.append(aligned(element))
        }
        return cases
    }

    /// A view stands at the size the tree states, its margin from its parent's corner.
    static func sized(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).standsAtItsStatedSizeInsideItsMargin", covers: [
            Covered(VisualElementContract.width, on: element), Covered(VisualElementContract.height, on: element),
            Covered(ViewContract.margin, on: element), Covered(ViewContract.frameChanged, on: element),
        ]) { s in
            let frames = Received<[Double]>()
            s.start {
                VStack {
                    specimen(element, frames, [
                        Write(VisualElementContract.width, 120), Write(VisualElementContract.height, 40),
                        Write(ViewContract.margin, Insets(10, 6, 0, 0)),
                    ])
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }

            s.settle { frames.values.last.map(place) == [10, 6, 120, 40] }
            s.expect(frames.values.last.map(place), [10, 6, 120, 40], "x, y, width, height in its parent")
        }
    }

    /// A stated size is held to the bounds the tree sets it.
    static func bounded(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).isHeldToTheBoundsTheTreeSets", covers: [
            Covered(VisualElementContract.maximumWidth, on: element),
            Covered(VisualElementContract.minimumWidth, on: element),
            Covered(VisualElementContract.maximumHeight, on: element),
            Covered(VisualElementContract.minimumHeight, on: element), Covered(ViewContract.frameChanged, on: element),
        ]) { s in
            let narrowed = Received<[Double]>()
            let widened = Received<[Double]>()
            s.start {
                VStack {
                    specimen(element, narrowed, [
                        Write(VisualElementContract.width, 120), Write(VisualElementContract.maximumWidth, 60),
                        Write(VisualElementContract.height, 20), Write(VisualElementContract.minimumHeight, 50),
                    ], id: "narrowed")
                    specimen(element, widened, [
                        Write(VisualElementContract.width, 20), Write(VisualElementContract.minimumWidth, 50),
                        Write(VisualElementContract.height, 120), Write(VisualElementContract.maximumHeight, 60),
                    ], id: "widened")
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }

            s.settle { narrowed.values.last.map(size) == [60, 50] && widened.values.last.map(size) == [50, 60] }
            s.expect(narrowed.values.last.map(size), [60, 50], "no wider than its maximum, no lower than its minimum")
            s.expect(widened.values.last.map(size), [50, 60], "no narrower than its minimum, no taller than its maximum")
        }
    }

    /// A view stands where its alignment puts it in the room its parent gives it.
    static func aligned(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).standsWhereItsAlignmentPutsIt", covers: [
            Covered(ViewContract.horizontalAlignment, on: element), Covered(ViewContract.verticalAlignment, on: element),
            Covered(ViewContract.frameChanged, on: element),
        ]) { s in
            let across = Received<[Double]>()
            let down = Received<[Double]>()
            s.start {
                VStack {
                    VStack {
                        specimen(element, across, [
                            Write(VisualElementContract.width, 100), Write(VisualElementContract.height, 20),
                            Write(ViewContract.horizontalAlignment, Alignment.end),
                        ], id: "across")
                    }
                    .width(300)
                    HStack {
                        specimen(element, down, [
                            Write(VisualElementContract.width, 20), Write(VisualElementContract.height, 40),
                            Write(ViewContract.verticalAlignment, Alignment.end),
                        ], id: "down")
                    }
                    .height(100)
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }

            s.settle { across.values.last.map(place)?[0] == 200 && down.values.last.map(place)?[1] == 60 }
            s.expect(across.values.last.map(place)?[0], 200, "at the end of a room 300 wide")
            s.expect(down.values.last.map(place)?[1], 60, "at the end of a room 100 high")
        }
    }

    /// `element`'s specimen wearing `worn`, its frames heard by `frames`.
    private static func specimen(
        _ element: String, _ frames: Received<[Double]>, _ worn: [any Worn], id: String = "specimen"
    ) -> any View {
        let heard = Hear(ViewContract.frameChanged) { numbers in frames.values.append(numbers) }
        return Specimens.make(element, Dressing(worn + [heard], id: id)) ?? Label("no specimen of \(element)")
    }

    /// A frame report's place in its parent, whole pixels: x, y, width, height.
    private static func place(_ numbers: [Double]) -> [Double] {
        numbers.prefix(4).map { $0.rounded() }
    }

    /// A frame report's size, whole pixels.
    private static func size(_ numbers: [Double]) -> [Double] {
        Array(place(numbers).dropFirst(2))
    }
}
