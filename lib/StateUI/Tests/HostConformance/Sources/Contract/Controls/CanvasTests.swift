// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// `CanvasContract` on a host: its instructions drawn in order and drawn again when the tree changes them, and a
/// press heard where it went down, where it was dragged and where it was let go, in the canvas's own points.
@_spi(Host) public enum CanvasTests: ConformanceFamily {
    public static let name = "Canvas"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("itsInstructionsAreDrawnInOrder", covers: [
                Covered(CanvasContract.self), Covered(CanvasContract.drawable),
            ]) { s in
                s.start {
                    VStack {
                        Canvas {
                            Draw.fillColor(.red)
                            Draw.fillRectangle(x: 0, y: 0, width: 80, height: 40)
                            Draw.fillColor(.blue)
                            Draw.fillRectangle(x: 50, y: 0, width: 20, height: 40)
                        }
                        .width(100).height(40).id("canvas")
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }
                let canvas = try s.element("canvas")

                try s.settle { try s.color(of: canvas, at: Point(10, 20)) == .red }
                s.expect(try s.color(of: canvas, at: Point(10, 20)), .red, "the first fill")
                s.expect(try s.color(of: canvas, at: Point(60, 20)), .blue, "the later fill over it")
                s.expect(try s.color(of: canvas, at: Point(95, 20)), nil, "nothing past both")
            },
            ConformanceCase("aDrawingTheTreeChangesIsDrawnAgain", covers: [
                Covered(CanvasContract.drawable), Covered(ButtonContract.clicked),
            ]) { s in
                let blue = State(wrappedValue: false)
                s.start {
                    VStack {
                        Canvas {
                            Draw.fillColor(blue.wrappedValue ? .blue : .red)
                            Draw.fillRectangle(x: 0, y: 0, width: 40, height: 40)
                        }
                        .width(40).height(40).id("canvas")
                        Button("Blue").onClicked { blue.wrappedValue = true }.id("change")
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }
                let canvas = try s.element("canvas")
                try s.settle { try s.color(of: canvas, at: Point(20, 20)) == .red }

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.color(of: canvas, at: Point(20, 20)) == .blue }
                s.expect(try s.color(of: canvas, at: Point(20, 20)), .blue)
            },
            ConformanceCase("aPressIsHeardWhereItWent", covers: [
                Covered(CanvasContract.pressed), Covered(CanvasContract.dragged), Covered(CanvasContract.released),
            ]) { s in
                let heard = Received<String>()
                s.start {
                    VStack {
                        Canvas { Draw.fillColor(.red); Draw.fillRectangle(x: 0, y: 0, width: 100, height: 40) }
                            .onPressed { heard.values.append("pressed \(Int($0.x)),\(Int($0.y))") }
                            .onDragged { heard.values.append("dragged \(Int($0.x)),\(Int($0.y))") }
                            .onReleased { heard.values.append("released \(Int($0.x)),\(Int($0.y))") }
                            .width(100).height(40).id("canvas")
                    }
                    .horizontalAlignment(.start)
                }
                let canvas = try s.element("canvas")

                try s.perform(.pressDown(at: Point(5, 6)), on: canvas)
                try s.perform(.drag(to: Point(7, 8)), on: canvas)
                try s.perform(.lift(at: Point(9, 10)), on: canvas)
                s.settle { heard.values.count == 3 }

                s.expect(heard.values, ["pressed 5,6", "dragged 7,8", "released 9,10"])
            },
        ]
    }
}
