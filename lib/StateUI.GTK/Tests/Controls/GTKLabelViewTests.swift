// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@testable import StateUIGTK
import XCTest

/// A word whose colour a button changes.
private struct ChangingRunPage: ContentView {
    @State private var red = true

    var content: any View {
        VStack {
            Label().spans { TextSpan("word").textColor(red ? Color("#FF0000") : Color("#0000FF")) }
            Button("Blue").onClicked { red = false }
        }
    }
}

/// One label, its words in spans until a button takes them away.
private struct SpannedPage: ContentView {
    @State private var spanned = true

    var content: any View {
        VStack {
            if spanned {
                Label("own").spans { TextSpan("runs") }.id("words")
            } else {
                Label("own").id("words")
            }
            Button("Plain").onClicked { spanned = false }
        }
    }
}

final class GTKLabelViewTests: XCTestCase {
    /// A label's words take the font, the colour, the spacing, the lines and the alignment the tree gives them.
    func testALabelTakesItsFontColourLinesAndAlignment() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                VStack {
                    Label("words")
                        .fontSize(20)
                        .fontAttributes([.bold, .italic])
                        .fontFamily("monospace")
                        .textColor(Color("#FF0000"))
                        .characterSpacing(2)
                        .lineHeight(1.5)
                        .textDecorations(.underline)
                        .maximumLines(2)
                        .horizontalTextAlignment(.center)
                }
            }
            let label = try XCTUnwrap(host.views(GTKLabelView.self).first)
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

    /// A label's padding is room between its edge and its words, on each side as the tree says.
    func testALabelsPaddingIsRoomAroundItsWords() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                VStack {
                    Label("words")
                    Label("words").padding(24, 8, 12, 4)
                }
            }
            let labels = host.views(GTKLabelView.self)
            let plain = try XCTUnwrap(labels.first).measure(width: nil, height: nil)
            let padded = try XCTUnwrap(labels.last).measure(width: nil, height: nil)

            XCTAssertEqual(padded.width - plain.width, 36, "24 on the left, 12 on the right")
            XCTAssertEqual(padded.height - plain.height, 12, "8 above, 4 below")
        }
    }

    /// A label cut short keeps to one line, or to as many as it is allowed; wrapping, it takes as many as its words.
    func testALabelKeepsToItsLines() {
        onUIThread {
            let words = "one two three four five six seven eight nine ten eleven twelve"
            let host = GTKRenderer.running {
                VStack {
                    Label(words).lineBreak(.tailTruncation)
                    Label(words).maximumLines(2)
                    Label(words)
                    Label("one")
                }
            }
            let heights = host.views(GTKLabelView.self).map { $0.measure(width: 120, height: nil).height }
            let line = heights[3]

            XCTAssertEqual(heights[0], line, "cut at its end on one line")
            XCTAssertEqual(heights[1], line * 2, accuracy: 2, "two lines, the second cut")
            XCTAssertGreaterThan(heights[2], line * 2, "every word shown")
        }
    }

    /// A label's spans are its words, run by run, each in its own colour, size, weight, slant, lines and background.
    func testALabelsSpansAreItsWordsRunByRun() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                VStack {
                    Label()
                        .spans {
                            TextSpan("let ").textColor(Color("#FF0000"))
                            TextSpan("x").fontSize(20).fontAttributes([.bold, .italic])
                            TextSpan(" = 1").textDecorations(.underline).background(Color("#FFFF00"))
                        }
                }
            }
            let label = try XCTUnwrap(host.views(GTKLabelView.self).first)

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

    /// A span that changes changes its run.
    func testASpanThatChangesChangesItsRun() throws {
        try onUIThread {
            let host = GTKRenderer.running { ChangingRunPage() }
            let label = try XCTUnwrap(host.views(GTKLabelView.self).first)
            XCTAssertEqual(label.ranged, ["0-4 foreground 65535 0 0", "0-4 foreground-alpha 65535"])

            try XCTUnwrap(host.views(GTKButtonView.self).first).click()
            host.pump.turn()

            XCTAssertEqual(label.ranged, ["0-4 foreground 0 0 65535", "0-4 foreground-alpha 65535"])
        }
    }

    /// A label whose spans are taken away shows its own words again.
    func testALabelWithoutItsSpansShowsItsOwnWords() throws {
        try onUIThread {
            let host = GTKRenderer.running { SpannedPage() }
            let label = try XCTUnwrap(host.views(GTKLabelView.self).first)
            XCTAssertEqual(label.text, "runs")

            try XCTUnwrap(host.views(GTKButtonView.self).first).click()
            host.pump.turn()

            XCTAssertTrue(host.views(GTKLabelView.self).first === label, "the same label, its spans gone")
            XCTAssertEqual(label.text, "own")
        }
    }
}

private extension GTKLabelView {
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
