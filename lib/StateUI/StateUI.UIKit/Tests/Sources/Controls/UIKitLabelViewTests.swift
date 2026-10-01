// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
import XCTest

/// A label's own box on UIKit.
final class UIKitLabelViewTests: XCTestCase {
    /// A label's background fills its whole box, the room around its words included - a colour, and a brush.
    @MainActor
    func testALabelsBackgroundFillsItsBox() {
        let label = UIKitLabelView()
        label.setText("Box")
        label.setPadding(Insets(12))
        label.frame = CGRect(x: 0, y: 0, width: 100, height: 60)
        label.setBackground(Color(red: 255, green: 0, blue: 0).propValue)
        XCTAssertTrue(Self.draws(label, [255, 0, 0], at: CGPoint(x: 3, y: 3)), "a colour, in the padding")

        label.setBackground(Brush.linearGradient([
            GradientStop(Color(red: 0, green: 0, blue: 255), 0), GradientStop(Color(red: 0, green: 0, blue: 255), 1),
        ]).propValue)
        // Core Animation renders a gradient a shade off its stops' colour into a bitmap.
        let corner = CGPoint(x: 97, y: 57)
        XCTAssertTrue(Self.draws(label, [0, 0, 255], at: corner, tolerance: 60), "a brush, to its corner")
    }

    /// Whether `view` draws `expected` - red, green and blue - at `point`, give or take `tolerance`.
    @MainActor
    private static func draws(_ view: UIView, _ expected: [Int], at point: CGPoint, tolerance: Int = 8) -> Bool {
        view.layer.displayIfNeeded()
        let (width, height) = (Int(view.bounds.width), Int(view.bounds.height))
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
            view.layer.render(in: context)
            return true
        }
        let offset = (Int(point.y) * width + Int(point.x)) * 4
        let read = drawn ? [Int(bytes[offset]), Int(bytes[offset + 1]), Int(bytes[offset + 2])] : []
        return read.count == 3 && zip(read, expected).allSatisfy { abs($0 - $1) <= tolerance }
    }
}
