// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

final class AppKitLabelViewTests: XCTestCase {
    @MainActor
    func testPlainLabelMapsTypographySpacingDecorationAndPadding() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        var label = HostPatch(id: .manual("label"), type: .label)
        label.properties = [
            .text: .string("StateUI"),
            .textTransform: .enumeration(TextTransform.uppercase.rawValue),
            .textColor: .color(red: 20, green: 40, blue: 60, alpha: 255),
            .fontSize: .number(18),
            .fontAttributes: .enumeration(FontAttributes.bold.rawValue),
            .characterSpacing: .number(2),
            .textDecorations: .enumeration(
                TextDecorations.underline.union(.strikethrough).rawValue),
            .lineHeight: .number(1.5),
            .padding: .numbers([4, 5, 6, 7]),
            .horizontalTextAlignment: .enumeration(TextAlignment.center.rawValue),
            .verticalTextAlignment: .enumeration(TextAlignment.end.rawValue),
        ]

        renderer.applyForTesting(tree(label))

        let native = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("label")) as? AppKitLabelView)
        let attributes = native.attributedStringValue.attributes(at: 0, effectiveRange: nil)
        XCTAssertEqual(native.stringValue, "STATEUI")
        XCTAssertEqual((attributes[.font] as? NSFont)?.pointSize, 18)
        XCTAssertEqual(attributes[.kern] as? Double, 2)
        XCTAssertEqual(attributes[.underlineStyle] as? Int, NSUnderlineStyle.single.rawValue)
        XCTAssertEqual(attributes[.strikethroughStyle] as? Int, NSUnderlineStyle.single.rawValue)
        XCTAssertEqual(native.padding.top, 5)
        XCTAssertEqual(native.padding.left, 4)
        XCTAssertEqual(native.padding.bottom, 7)
        XCTAssertEqual(native.padding.right, 6)
        XCTAssertEqual(native.horizontalTextAlignment, .center)
        XCTAssertEqual(native.verticalTextAlignment, .end)
    }

    @MainActor
    func testFormattedSpansBecomeOneAttributedNativeString() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        var first = HostPatch(id: .manual("first"), type: .span)
        first.properties = [
            .text: .string("let "),
            .textColor: .color(red: 128, green: 0, blue: 128, alpha: 255),
            .fontAttributes: .enumeration(FontAttributes.bold.rawValue),
        ]
        var second = HostPatch(id: .manual("second"), type: .span)
        second.properties = [
            .text: .string("counter"),
            .background: .color(red: 240, green: 230, blue: 140, alpha: 255),
            .textTransform: .enumeration(TextTransform.uppercase.rawValue),
        ]
        var formatted = HostPatch(id: .manual("formatted"), type: .formattedString)
        formatted.children = .arranged([first, second])
        var label = HostPatch(id: .manual("label"), type: .label)
        label.properties[.fontSize] = .number(15)
        label.children = .arranged([formatted])

        renderer.applyForTesting(tree(label))

        let native = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("label")) as? AppKitLabelView)
        XCTAssertEqual(native.stringValue, "let COUNTER")
        XCTAssertNotNil(native.attributedStringValue.attribute(
            .foregroundColor, at: 0, effectiveRange: nil) as? NSColor)
        XCTAssertNotNil(native.attributedStringValue.attribute(
            .backgroundColor, at: 4, effectiveRange: nil) as? NSColor)
        XCTAssertTrue(
            (native.attributedStringValue.attribute(.font, at: 0, effectiveRange: nil)
                as? NSFont)?.fontDescriptor.symbolicTraits.contains(.bold) == true)
    }

    @MainActor
    func testSparseSpanPatchLeavesEveryOtherRunUnchanged() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        var first = HostPatch(id: .manual("first"), type: .span)
        first.properties = [.text: .string("A"), .textColor: .color(
            red: 0, green: 0, blue: 0, alpha: 255)]
        var second = HostPatch(id: .manual("second"), type: .span)
        second.properties = [.text: .string("B"), .textColor: .color(
            red: 0, green: 0, blue: 255, alpha: 255)]
        var formatted = HostPatch(id: .manual("formatted"), type: .formattedString)
        formatted.children = .arranged([first, second])
        var label = HostPatch(id: .manual("label"), type: .label)
        label.children = .arranged([formatted])
        renderer.applyForTesting(tree(label))

        var changedSecond = HostPatch(id: .manual("second"), type: .span)
        changedSecond.properties[.textColor] = .color(
            red: 255, green: 0, blue: 0, alpha: 255)
        var changedFormatted = HostPatch(id: .manual("formatted"), type: .formattedString)
        changedFormatted.children = .changed([changedSecond])
        var changedLabel = HostPatch(id: .manual("label"), type: .label)
        changedLabel.children = .changed([changedFormatted])
        renderer.applyForTesting(changedTree(changedLabel))

        let native = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("label")) as? AppKitLabelView)
        XCTAssertEqual(native.stringValue, "AB")
        let firstColor = try XCTUnwrap((native.attributedStringValue.attribute(
            .foregroundColor, at: 0, effectiveRange: nil) as? NSColor)?.usingColorSpace(.sRGB))
        let secondColor = try XCTUnwrap((native.attributedStringValue.attribute(
            .foregroundColor, at: 1, effectiveRange: nil) as? NSColor)?.usingColorSpace(.sRGB))
        XCTAssertEqual(firstColor.redComponent, 0, accuracy: 0.001)
        XCTAssertEqual(secondColor.redComponent, 1, accuracy: 0.001)
    }

    @MainActor
    func testVerticalAlignmentUsesThePaddedContentRectangle() {
        let view = AppKitLabelView()
        view.frame = NSRect(x: 0, y: 0, width: 100, height: 80)
        view.apply(
            attributedText: NSAttributedString(
                string: "one line", attributes: [.font: NSFont.systemFont(ofSize: 12)]),
            padding: NSEdgeInsets(top: 6, left: 4, bottom: 10, right: 8),
            horizontalAlignment: .left,
            verticalAlignment: .end,
            lineBreakMode: .byClipping,
            maximumNumberOfLines: 1)

        view.layoutSubtreeIfNeeded()

        XCTAssertEqual(view.textFrame.minX, 4, accuracy: 0.001)
        XCTAssertEqual(view.textFrame.maxY, 70, accuracy: 0.001)
        XCTAssertLessThan(view.textFrame.height, 64)
    }

    @MainActor
    func testAWidthConstraintMeasuresWrappingWithoutInventingFill() {
        let view = AppKitLabelView()
        view.apply(
            attributedText: NSAttributedString(
                string: "short", attributes: [.font: NSFont.systemFont(ofSize: 13)]),
            padding: NSEdgeInsets(top: 2, left: 5, bottom: 3, right: 7),
            horizontalAlignment: .left,
            verticalAlignment: .start,
            lineBreakMode: .byWordWrapping,
            maximumNumberOfLines: 0)

        let measured = view.fittingContentSize(width: 300)

        XCTAssertLessThan(measured.width, 100)
        XCTAssertGreaterThanOrEqual(measured.width, 12)
    }

    @MainActor
    func testMaximumLinesUsesTheAuthoredParagraphLineHeight() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 30
        paragraph.maximumLineHeight = 30
        let view = AppKitLabelView()
        view.apply(
            attributedText: NSAttributedString(
                string: "one\ntwo\nthree",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 10),
                    .paragraphStyle: paragraph,
                ]),
            padding: NSEdgeInsets(),
            horizontalAlignment: .left,
            verticalAlignment: .start,
            lineBreakMode: .byWordWrapping,
            maximumNumberOfLines: 2)

        XCTAssertEqual(view.fittingContentSize(width: 100).height, 60, accuracy: 1)
    }
}

#endif
