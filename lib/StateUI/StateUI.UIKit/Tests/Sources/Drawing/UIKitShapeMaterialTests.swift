// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
import UIKit
import XCTest

/// Glass shows within its figure alone - a corner the figure leaves bare shows what stands under it - whether a
/// shape is made of it or a layout stands on it: shaped by its corners where the figure is a rounded rectangle, and
/// as the blur standing in for it, cut to the figure, where it is not.
@MainActor
final class UIKitShapeMaterialTests: XCTestCase {
    private static let red = (red: 255, green: 0, blue: 0)

    func testAGlassCircleLeavesItsCornersBare() throws {
        let host = Self.overRed {
            Ellipse()
                .fill(.glass(.clear))
                .width(64)
                .height(64)
        }
        defer { host.finish() }
        let figure = try XCTUnwrap(host.views(UIKitShapeView.self).first)

        try Self.expectBare(figure, at: CGPoint(x: 2, y: 2), "a corner the circle leaves bare")
        XCTAssertNotNil(figure.backdropForTesting?.shown?.glass, "the circle is glass")
    }

    func testAGlassOvalIsMadeOfItsBlurCutToIt() throws {
        let host = Self.overRed {
            Ellipse()
                .fill(.glass(.clear))
                .width(96)
                .height(48)
        }
        defer { host.finish() }
        let figure = try XCTUnwrap(host.views(UIKitShapeView.self).first)

        try Self.expectBare(figure, at: CGPoint(x: 3, y: 3), "a corner the oval leaves bare")
        let shown = try XCTUnwrap(figure.backdropForTesting?.shown)
        XCTAssertNil(shown.glass, "no rounded rectangle is an oval of two lengths")
        XCTAssertNotNil(shown.blur, "the blur standing in for the glass")
    }

    func testAnOvalLayoutOfGlassLeavesItsCornersBare() throws {
        let host = Self.overRed {
            ZStack {}
                .width(64)
                .height(64)
                .shape(.ellipse)
                .background(.glass(.clear))
        }
        defer { host.finish() }
        let layout = try XCTUnwrap(host.views(UIKitZStackView.self).first { $0.bounds.width == 64 })

        try Self.expectBare(layout, at: CGPoint(x: 2, y: 2), "a corner the circle leaves bare")
    }

    /// A host showing `figure` in the middle of a red square, settled until the screen shows it.
    private static func overRed(_ figure: @escaping @MainActor () -> some View) -> UIKitRenderer {
        let host = UIKitRenderer.running {
            VStack {
                ZStack {
                    Fill(Color(red: 255, green: 0, blue: 0))
                    figure()
                }
                .width(120)
                .height(120)
            }
            .horizontalAlignment(.start)
            .verticalAlignment(.start)
        }
        var turns = 0
        host.settle { turns += 1; return turns > 30 }
        return host
    }

    /// Expects the screen to show the red under `view` at `point` of it.
    private static func expectBare(
        _ view: UIView, at point: CGPoint, _ message: String, line: UInt = #line
    ) throws {
        let window = try XCTUnwrap(view.window)
        let shown = try XCTUnwrap(color(in: window, at: view.convert(point, to: window)))
        XCTAssertEqual(shown.red, red.red, accuracy: 6, message, line: line)
        XCTAssertEqual(shown.green, red.green, accuracy: 6, message, line: line)
        XCTAssertEqual(shown.blue, red.blue, accuracy: 6, message, line: line)
    }

    /// The color the screen shows at `point` of `window`, in sRGB.
    private static func color(in window: UIWindow, at point: CGPoint) -> (red: Int, green: Int, blue: Int)? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.preferredRange = .standard
        let drawn = UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        guard let image = drawn.cgImage, let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = context.data
        else { return nil }
        // The one pixel at `point` drawn into a context of one, whose row stands at the image's bottom.
        context.draw(image, in: CGRect(
            x: -point.x.rounded(.down), y: point.y.rounded(.down) - CGFloat(image.height) + 1,
            width: CGFloat(image.width), height: CGFloat(image.height)))
        let pixel = data.assumingMemoryBound(to: UInt8.self)
        return (Int(pixel[0]), Int(pixel[1]), Int(pixel[2]))
    }
}
