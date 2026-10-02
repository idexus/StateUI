// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
@testable import StateUIGTKDriver
import XCTest

/// A word whose colour a button changes.
private struct ChangingRunPage: View {
    @State private var red = true

    var body: some View {
        VStack {
            Text().spans { TextSpan("word").textColor(red ? Color("#FF0000") : Color("#0000FF")) }
            Button("Blue").onClicked { red = false }
        }
    }
}

/// One label, its words in spans until a button takes them away.
private struct SpannedPage: View {
    @State private var spanned = true

    var body: some View {
        VStack {
            if spanned {
                Text("own").spans { TextSpan("runs") }.id("words")
            } else {
                Text("own").id("words")
            }
            Button("Plain").onClicked { spanned = false }
        }
    }
}

final class GTKTextViewTests: XCTestCase {
    /// A label's words take the font, the colour, the spacing, the lines and the alignment the tree gives them.
    func testATextTakesItsFontColourLinesAndAlignment() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                VStack {
                    Text("words")
                        .fontSize(20)
                        .fontAttributes([.bold, .italic])
                        .fontFamily("monospace")
                        .textColor(Color("#FF0000"))
                        .tracking(2)
                        .lineHeight(1.5)
                        .textDecorations(.underline)
                        .maximumLines(2)
                        .horizontalTextAlignment(.center)
                }
            }
            let label = try XCTUnwrap(host.views(GTKTextView.self).first)
            let said = label.attributes

            XCTAssertEqual(said[PANGO_ATTR_ABSOLUTE_SIZE.rawValue], "\(20 * PANGO_SCALE)")
            XCTAssertEqual(said[PANGO_ATTR_WEIGHT.rawValue], "\(PANGO_WEIGHT_BOLD.rawValue)")
            XCTAssertEqual(said[PANGO_ATTR_STYLE.rawValue], "\(PANGO_STYLE_ITALIC.rawValue)")
            XCTAssertEqual(said[PANGO_ATTR_FAMILY.rawValue], "monospace")
            XCTAssertEqual(said[PANGO_ATTR_FOREGROUND.rawValue], "65535 0 0")
            XCTAssertEqual(said[PANGO_ATTR_LETTER_SPACING.rawValue], "\(2 * PANGO_SCALE)")
            XCTAssertEqual(said[PANGO_ATTR_LINE_HEIGHT.rawValue], "1.5")
            XCTAssertEqual(said[PANGO_ATTR_UNDERLINE.rawValue], "\(PANGO_UNDERLINE_SINGLE.rawValue)")
            XCTAssertEqual(gtk_label_get_lines(label.widget.opaque), 2)
            XCTAssertEqual(gtk_label_get_ellipsize(label.widget.opaque), PANGO_ELLIPSIZE_END)
            XCTAssertEqual(gtk_label_get_xalign(label.widget.opaque), 0.5)
            XCTAssertEqual(gtk_label_get_justify(label.widget.opaque), GTK_JUSTIFY_CENTER)
        }
    }

    /// A label's box takes its background, and its words stand down its height where the tree says.
    func testATextsBackgroundFillsItsBoxAndItsWordsStandDownIt() {
        onUIThread {
            let host = GTKRenderer.running {
                VStack {
                    Text("7").background(Color("#FF0000")).verticalTextAlignment(.end).width(60).height(72)
                    Text("at the top").height(72)
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            let labels = host.views(GTKTextView.self)
            host.settle { labels[0].pixels(at: [(2, 2)]) != [0] }

            XCTAssertEqual(labels[0].pixels(at: [(2, 2), (58, 70)]), [0xFFFF_0000, 0xFFFF_0000], "filled corner to corner")
            XCTAssertEqual(gtk_label_get_yalign(labels[0].widget.opaque), 1, "at the bottom")
            XCTAssertEqual(gtk_label_get_yalign(labels[1].widget.opaque), 0, "at the top unless told")
        }
    }

    /// A label's padding is room between its edge and its words, on each side as the tree says.
    func testATextsPaddingIsRoomAroundItsWords() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                VStack {
                    Text("words")
                    Text("words").padding(24, 8, 12, 4)
                }
            }
            let labels = host.views(GTKTextView.self)
            let plain = try XCTUnwrap(labels.first).measure(width: nil, height: nil)
            let padded = try XCTUnwrap(labels.last).measure(width: nil, height: nil)

            XCTAssertEqual(padded.width - plain.width, 36, "24 on the left, 12 on the right")
            XCTAssertEqual(padded.height - plain.height, 12, "8 above, 4 below")
        }
    }

    /// A label cut short keeps to one line, however many it is allowed (`LineBreak.lines`); wrapping, it keeps to
    /// as many as it is allowed, else takes as many as its words.
    func testATextKeepsToItsLines() {
        onUIThread {
            let words = "one two three four five six seven eight nine ten eleven twelve"
            let host = GTKRenderer.running {
                VStack {
                    Text(words).lineBreak(.tailTruncation)
                    Text(words).maximumLines(2)
                    Text(words)
                    Text("one")
                    Text(words).lineBreak(.tailTruncation).maximumLines(3)
                }
            }
            let heights = host.views(GTKTextView.self).map { $0.measure(width: 120, height: nil).height }
            let line = heights[3]

            XCTAssertEqual(heights[0], line, "cut at its end on one line")
            XCTAssertEqual(heights[1], line * 2, accuracy: 2, "two lines, the second cut")
            XCTAssertGreaterThan(heights[2], line * 2, "every word shown")
            XCTAssertEqual(heights[4], line, "cut short on one line, though three are allowed")
        }
    }

    /// A label's spans are its words, run by run, each in its own colour, size, weight, slant, lines and background.
    func testATextsSpansAreItsWordsRunByRun() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                VStack {
                    Text()
                        .spans {
                            TextSpan("let ").textColor(Color("#FF0000"))
                            TextSpan("x").fontSize(20).fontAttributes([.bold, .italic])
                            TextSpan(" = 1").textDecorations(.underline).background(Color("#FFFF00"))
                        }
                }
            }
            let label = try XCTUnwrap(host.views(GTKTextView.self).first)

            XCTAssertEqual(label.text, "let x = 1")
            XCTAssertEqual(label.ranged, [
                "0-4 foreground 65535 0 0", "0-4 foreground-alpha 65535",
                "4-5 size \(20 * PANGO_SCALE)", "4-5 style \(PANGO_STYLE_ITALIC.rawValue)",
                "4-5 weight \(PANGO_WEIGHT_BOLD.rawValue)",
                "5-9 background 65535 65535 0", "5-9 background-alpha 65535",
                "5-9 underline \(PANGO_UNDERLINE_SINGLE.rawValue)",
            ])
        }
    }

    /// A span that changes changes its run, its colour travelling there.
    func testASpanThatChangesChangesItsRun() throws {
        try onUIThread {
            let host = GTKRenderer.running { ChangingRunPage() }
            let label = try XCTUnwrap(host.views(GTKTextView.self).first)
            XCTAssertEqual(label.ranged, ["0-4 foreground 65535 0 0", "0-4 foreground-alpha 65535"])

            try XCTUnwrap(host.views(GTKButtonView.self).first).click()
            let blue = ["0-4 foreground 0 0 65535", "0-4 foreground-alpha 65535"]
            host.settle { label.ranged == blue }

            XCTAssertEqual(label.ranged, blue)
        }
    }

    /// A label whose spans are taken away shows its own words again.
    func testATextWithoutItsSpansShowsItsOwnWords() throws {
        try onUIThread {
            let host = GTKRenderer.running { SpannedPage() }
            let label = try XCTUnwrap(host.views(GTKTextView.self).first)
            XCTAssertEqual(label.text, "runs")

            try XCTUnwrap(host.views(GTKButtonView.self).first).click()
            host.runtime.pump.turn()

            XCTAssertTrue(host.views(GTKTextView.self).first === label, "the same label, its spans gone")
            XCTAssertEqual(label.text, "own")
        }
    }
}

private extension GTKTextView {
    /// Each of the label's Pango attributes over the bytes it covers, as "start-end kind value", in order.
    var ranged: [String] {
        guard let list = gtk_label_get_attributes(widget.opaque) else { return [] }
        var said: [String] = []
        let first = pango_attr_list_get_attributes(list)
        var each = first
        while let node = each {
            let attribute = node.pointee.data.assumingMemoryBound(to: PangoAttribute.self)
            let kind = Self.kinds[attribute.pointee.klass.pointee.type.rawValue] ?? "?"
            said.append("\(attribute.pointee.start_index)-\(attribute.pointee.end_index) \(kind) \(Self.describe(attribute))")
            each = node.pointee.next
        }
        g_slist_free_full(first) { pango_attribute_destroy($0?.assumingMemoryBound(to: PangoAttribute.self)) }
        return said.sorted()
    }

    /// What each of the label's Pango attributes says, by its type: a number, a family, a colour's channels.
    var attributes: [UInt32: String] {
        guard let list = gtk_label_get_attributes(widget.opaque) else { return [:] }
        var said: [UInt32: String] = [:]
        let first = pango_attr_list_get_attributes(list)
        var each = first
        while let node = each {
            let attribute = node.pointee.data.assumingMemoryBound(to: PangoAttribute.self)
            said[attribute.pointee.klass.pointee.type.rawValue] = Self.describe(attribute)
            each = node.pointee.next
        }
        g_slist_free_full(first) { pango_attribute_destroy($0?.assumingMemoryBound(to: PangoAttribute.self)) }
        return said
    }

    private static let kinds: [UInt32: String] = [
        PANGO_ATTR_FOREGROUND.rawValue: "foreground", PANGO_ATTR_FOREGROUND_ALPHA.rawValue: "foreground-alpha",
        PANGO_ATTR_BACKGROUND.rawValue: "background", PANGO_ATTR_BACKGROUND_ALPHA.rawValue: "background-alpha",
        PANGO_ATTR_ABSOLUTE_SIZE.rawValue: "size", PANGO_ATTR_WEIGHT.rawValue: "weight",
        PANGO_ATTR_STYLE.rawValue: "style", PANGO_ATTR_UNDERLINE.rawValue: "underline",
    ]

    private static func describe(_ attribute: UnsafeMutablePointer<PangoAttribute>) -> String {
        let raw = UnsafeMutableRawPointer(attribute)
        switch attribute.pointee.klass.pointee.type {
        case PANGO_ATTR_ABSOLUTE_SIZE:
            return "\(raw.assumingMemoryBound(to: PangoAttrSize.self).pointee.size)"
        case PANGO_ATTR_FAMILY:
            return String(cString: raw.assumingMemoryBound(to: PangoAttrString.self).pointee.value)
        case PANGO_ATTR_FOREGROUND, PANGO_ATTR_BACKGROUND:
            let color = raw.assumingMemoryBound(to: PangoAttrColor.self).pointee.color
            return "\(color.red) \(color.green) \(color.blue)"
        case PANGO_ATTR_LINE_HEIGHT:
            return "\(raw.assumingMemoryBound(to: PangoAttrFloat.self).pointee.value)"
        default:
            return "\(raw.assumingMemoryBound(to: PangoAttrInt.self).pointee.value)"
        }
    }
}
