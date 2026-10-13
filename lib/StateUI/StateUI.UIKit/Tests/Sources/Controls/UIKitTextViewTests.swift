// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
import XCTest

/// A label's own box on UIKit.
@MainActor
final class UIKitTextViewTests: XCTestCase {
    /// Words the user selects stand as a label's: the same height for the same words and padding, measured the
    /// same wherever they stand, and at the room's foot where the tree aligns them there - and they can be selected.
    @MainActor
    func testSelectableWordsStandAsALabelsDo() {
        let label = UIKitTextView()
        let selectable = UIKitSelectableTextView()
        for view in [label, selectable] as [any UIKitLabel] {
            view.setText("Some words, long enough to wrap onto a second line in a narrow room")
            view.setPadding(Insets(6))
        }
        let room = CGSize(width: 200, height: CGFloat.greatestFiniteMagnitude)
        let height = label.sizeThatFits(room).height
        XCTAssertEqual(selectable.sizeThatFits(room).height, height, accuracy: 2, "the label's height")
        XCTAssertTrue(selectable.isSelectable && !selectable.isEditable, "selected, never edited")

        selectable.setAlignment(horizontal: .start, vertical: .end)
        selectable.frame = CGRect(x: 0, y: 0, width: 200, height: height + 100)
        selectable.layoutIfNeeded()
        XCTAssertEqual(selectable.textContainerInset.top, 106, accuracy: 2, "at the room's foot, within the padding")
        XCTAssertEqual(selectable.sizeThatFits(room).height, height, accuracy: 2, "measured as it was")
    }

    /// A label resized draws its words again, whatever its height comes to: words drawn for one width and stretched
    /// to another break their lines anew only when something else has them drawn.
    @MainActor
    func testALabelResizedDrawsItsWordsAgain() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 1100, height: 400))
        window.isHidden = false
        defer { window.isHidden = true }
        let label = UIKitTextView()
        label.setLook { $0.size = 13 }
        label.setText(
            "Each hand is a box whose bottom sits at the face's centre - its pivot - turned about that point, so "
                + "a hand drawn upright points at twelve.")
        window.addSubview(label)
        label.frame = CGRect(x: 20, y: 20, width: 984, height: 31.5)
        window.layoutIfNeeded()
        label.layer.displayIfNeeded()
        XCTAssertFalse(label.layer.needsDisplay())

        label.bounds.size = CGSize(width: 664, height: 31.5)
        label.layoutIfNeeded()
        XCTAssertTrue(label.layer.needsDisplay(), "narrower, its height the same")
    }

    /// Words measured without a width are not measured again in a wider room - a long listing in a scroller laid
    /// out as wide as its document each frame a page widens - but are in a narrower one, and once their words change.
    @MainActor
    func testWordsMeasuredWithoutAWidthAreNotMeasuredAgainInAWiderRoom() {
        let label = UIKitTextView()
        label.setText("Some words, long enough to wrap onto a second line in a narrow room")
        let unbounded = CGFloat.greatestFiniteMagnitude
        let natural = label.sizeThatFits(CGSize(width: unbounded, height: unbounded))
        XCTAssertEqual(label.sizeThatFits(CGSize(width: natural.width + 200, height: unbounded)), natural)
        XCTAssertEqual(label.sizeThatFits(CGSize(width: natural.width + 300, height: unbounded)), natural)
        XCTAssertEqual(label.nativeMeasurementCountForTesting, 1, "measured once")

        XCTAssertGreaterThan(label.sizeThatFits(CGSize(width: 120, height: unbounded)).height, natural.height)
        label.setText("Other words")
        _ = label.sizeThatFits(CGSize(width: natural.width + 200, height: unbounded))
        XCTAssertEqual(label.nativeMeasurementCountForTesting, 3, "a narrower room, then new words, are measured")
    }

    /// A label's background fills its whole box, the room around its words included - a colour, and a brush.
    @MainActor
    func testATextsBackgroundFillsItsBox() {
        let label = UIKitTextView()
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
