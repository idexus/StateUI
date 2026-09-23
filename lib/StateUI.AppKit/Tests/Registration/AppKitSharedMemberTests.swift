// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

/// A member many controls share reaches, through the host, the native
/// control of every entry that realizes it.
final class AppKitSharedMemberTests: XCTestCase {
    /// Every control a user operates is disabled by `isEnabled(false)` and
    /// enabled again by `isEnabled(true)`.
    @MainActor
    func testEveryOperableControlFollowsIsEnabled() throws {
        let controls: [(NodeType, [Prop: HostValue], @MainActor (NSView) -> Bool?)] = [
            (.button, [.text: .string("Save")], { ($0 as? NSControl)?.isEnabled }),
            (.checkBox, [:], { ($0 as? NSControl)?.isEnabled }),
            (.radioButton, [.text: .string("One")], { ($0 as? NSControl)?.isEnabled }),
            (.switch, [:], { ($0 as? NSControl)?.isEnabled }),
            (.slider, [:], { ($0 as? NSControl)?.isEnabled }),
            (.stepper, [:], { ($0 as? NSControl)?.isEnabled }),
            (.datePicker, [:], { ($0 as? NSControl)?.isEnabled }),
            (.timePicker, [:], { ($0 as? NSControl)?.isEnabled }),
            (.searchField, [:], { ($0 as? NSControl)?.isEnabled }),
            (.textField, [:], { ($0 as? AppKitTextFieldView)?.textField.isEnabled }),
            (.textEditor, [:], { ($0 as? AppKitTextEditorView)?.textView.isSelectable }),
            (.picker, [.options: .strings(["One"])], { ($0 as? AppKitPickerView)?.isEnabled }),
        ]

        for (type, properties, isEnabled) in controls {
            let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
            defer { renderer.closeForTesting() }
            var disabled = HostPatch(id: .manual("control"), type: type)
            disabled.properties = properties
            disabled.properties[.isEnabled] = .bool(false)
            renderer.applyForTesting(tree(disabled))
            let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("control")), type.name)
            XCTAssertEqual(isEnabled(native), false, type.name)

            var enabled = HostPatch(id: .manual("control"), type: type)
            enabled.properties[.isEnabled] = .bool(true)
            renderer.applyForTesting(changedTree(enabled))
            XCTAssertEqual(isEnabled(native), true, type.name)
        }
    }

    /// A control that sets text sets it in the size, the family, and the
    /// weight and slant that `fontSize`, `fontFamily` and `fontAttributes` say.
    @MainActor
    func testEveryTextControlSetsItsTextInTheWrittenFont() throws {
        let controls: [(NodeType, [Prop: HostValue], @MainActor (NSView) -> NSFont?)] = [
            (.label, [.text: .string("Text")], {
                ($0 as? AppKitLabelView)?.attributedStringValue
                    .attribute(.font, at: 0, effectiveRange: nil) as? NSFont
            }),
            (.button, [.text: .string("Text")], { ($0 as? NSButton)?.font }),
            (.radioButton, [.text: .string("Text")], { ($0 as? NSButton)?.font }),
            (.textField, [.text: .string("Text")], { ($0 as? AppKitTextFieldView)?.textField.font }),
            (.textEditor, [.text: .string("Text")], { ($0 as? AppKitTextEditorView)?.textView.font }),
            (.searchField, [.text: .string("Text")], { ($0 as? NSSearchField)?.font }),
            (.picker, [.options: .strings(["Text"])], { ($0 as? AppKitPickerView)?.font }),
            (.datePicker, [:], { ($0 as? NSDatePicker)?.font }),
            (.timePicker, [:], { ($0 as? NSDatePicker)?.font }),
        ]

        for (type, properties, nativeFont) in controls {
            let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
            defer { renderer.closeForTesting() }
            var control = HostPatch(id: .manual("control"), type: type)
            control.properties = properties.merging([
                .fontSize: .number(21),
                .fontFamily: .name("Menlo"),
                .fontAttributes: .enumeration(FontAttributes([.bold, .italic]).rawValue),
            ]) { $1 }
            renderer.applyForTesting(tree(control))

            let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("control")), type.name)
            let font = try XCTUnwrap(nativeFont(native), type.name)
            let traits = NSFontManager.shared.traits(of: font)
            XCTAssertEqual(font.pointSize, 21, type.name)
            XCTAssertEqual(font.familyName, "Menlo", type.name)
            XCTAssertTrue(traits.contains(.boldFontMask), type.name)
            XCTAssertTrue(traits.contains(.italicFontMask), type.name)
        }
    }

    /// A control that sets text sets it in the colour `textColor` says.
    @MainActor
    func testEveryTextControlSetsItsTextInTheWrittenColour() throws {
        func foreground(_ text: NSAttributedString?) -> NSColor? {
            text?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        }
        let controls: [(NodeType, [Prop: HostValue], @MainActor (NSView) -> NSColor?)] = [
            (.label, [.text: .string("Text")], {
                foreground(($0 as? AppKitLabelView)?.attributedStringValue)
            }),
            (.button, [.text: .string("Text")], { foreground(($0 as? NSButton)?.attributedTitle) }),
            (.radioButton, [.text: .string("Text")], { foreground(($0 as? NSButton)?.attributedTitle) }),
            (.textField, [.text: .string("Text")], { ($0 as? AppKitTextFieldView)?.textField.textColor }),
            (.textEditor, [.text: .string("Text")], { ($0 as? AppKitTextEditorView)?.textView.textColor }),
            (.searchField, [.text: .string("Text")], { ($0 as? NSSearchField)?.textColor }),
            (.picker, [.options: .strings(["Text"])], { picker in
                let button = picker.subviews.compactMap { $0 as? NSPopUpButton }.first
                return foreground(button?.itemArray.first?.attributedTitle)
            }),
            (.datePicker, [:], { ($0 as? NSDatePicker)?.textColor }),
            (.timePicker, [:], { ($0 as? NSDatePicker)?.textColor }),
        ]

        for (type, properties, nativeColour) in controls {
            let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
            defer { renderer.closeForTesting() }
            var control = HostPatch(id: .manual("control"), type: type)
            control.properties = properties
            control.properties[.textColor] = .color(red: 51, green: 102, blue: 153, alpha: 255)
            renderer.applyForTesting(tree(control))

            let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("control")), type.name)
            assertChannels(channels(nativeColour(native)), [0.2, 0.4, 0.6, 1], type.name)
        }
    }

    /// A background colour paints the view it is written on: its layer, or -
    /// for a colour box, which draws its own colours - its drawing.
    @MainActor
    func testABackgroundColourPaintsEveryView() throws {
        let layered: [NodeType] = [
            .absoluteLayout, .activityIndicator, .button, .canvas, .checkBox, .datePicker,
            .ellipse, .grid, .hStack, .image, .label, .line, .path, .picker, .polygon,
            .polyline, .progressBar, .radioButton, .rectangle, .scrollView, .searchField,
            .slider, .stepper, .switch, .textEditor, .textField, .timePicker, .vStack,
        ]

        for type in layered + [.colorBox] {
            let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
            defer { renderer.closeForTesting() }
            var view = HostPatch(id: .manual("view"), type: type)
            view.properties[.background] = .color(red: 51, green: 102, blue: 153, alpha: 255)
            renderer.applyForTesting(tree(view))

            let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("view")), type.name)
            let painted = type == .colorBox
                ? channels((native as? AppKitColorBoxView)?.backgroundColor)
                : channels(native.layer?.backgroundColor)
            assertChannels(painted, [0.2, 0.4, 0.6, 1], type.name)
        }
    }

    /// A view that ignores input is not hit, and nothing in it is; the same
    /// view that does not is hit where it stands.
    @MainActor
    func testAViewThatIgnoresInputIsNotHit() throws {
        let views: [NodeType] = [
            .absoluteLayout, .border, .canvas, .colorBox, .ellipse, .grid, .hStack, .image,
            .label, .line, .path, .polygon, .polyline, .rectangle, .vStack,
        ]

        for type in views {
            let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
            defer { renderer.closeForTesting() }
            func placed(_ id: String, ignoresInput: Bool) -> HostPatch {
                var view = HostPatch(id: .manual(id), type: type)
                view.properties = [
                    .width: .number(40),
                    .height: .number(20),
                    .horizontalAlignment: .enumeration(Alignment.start.rawValue),
                    .ignoresInput: .bool(ignoresInput),
                ]
                return view
            }
            var stack = HostPatch(id: .manual("stack"), type: .vStack)
            stack.children = .arranged([
                placed("answering", ignoresInput: false),
                placed("ignoring", ignoresInput: true),
            ])
            renderer.applyForTesting(tree(stack))

            let nativeStack = try XCTUnwrap(renderer.viewForTesting(id: .manual("stack")), type.name)
            nativeStack.frame = NSRect(x: 0, y: 0, width: 200, height: 100)
            nativeStack.layoutSubtreeIfNeeded()
            let answering = try XCTUnwrap(renderer.viewForTesting(id: .manual("answering")), type.name)
            let ignoring = try XCTUnwrap(renderer.viewForTesting(id: .manual("ignoring")), type.name)

            XCTAssertNotNil(
                answering.hitTest(NSPoint(x: answering.frame.midX, y: answering.frame.midY)), type.name)
            XCTAssertNil(
                ignoring.hitTest(NSPoint(x: ignoring.frame.midX, y: ignoring.frame.midY)), type.name)
        }
    }

    /// A layout that lets input through is not hit on its own empty room -
    /// a point there reaches whatever stands behind it - while what it holds
    /// still is.
    @MainActor
    func testALayoutThatLetsInputThroughStillHasItsChildrenHit() throws {
        for type in [NodeType.vStack, .hStack, .grid, .absoluteLayout] {
            let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
            defer { renderer.closeForTesting() }
            var child = HostPatch(id: .manual("child"), type: .colorBox)
            child.properties = [
                .width: .number(20),
                .height: .number(20),
                .horizontalAlignment: .enumeration(Alignment.start.rawValue),
                .verticalAlignment: .enumeration(Alignment.start.rawValue),
                .absoluteLayoutBounds: .numbers([0, 0, 20, 20]),
            ]
            var layout = HostPatch(id: .manual("layout"), type: type)
            layout.properties[.letsInputThrough] = .bool(true)
            layout.children = .arranged([child])
            renderer.applyForTesting(tree(layout))

            let nativeLayout = try XCTUnwrap(renderer.viewForTesting(id: .manual("layout")), type.name)
            let nativeChild = try XCTUnwrap(renderer.viewForTesting(id: .manual("child")), type.name)
            nativeLayout.frame = NSRect(x: 0, y: 0, width: 100, height: 100)
            nativeLayout.layoutSubtreeIfNeeded()
            let onChild = nativeLayout.convert(
                NSPoint(x: nativeChild.frame.midX, y: nativeChild.frame.midY),
                to: nativeLayout.superview)
            let onRoom = nativeLayout.convert(NSPoint(x: 90, y: 90), to: nativeLayout.superview)

            XCTAssertTrue(nativeLayout.hitTest(onChild) === nativeChild, type.name)
            XCTAssertNil(nativeLayout.hitTest(onRoom), type.name)
        }
    }
}

/// The four sRGB channels of `color`, or nil when there is none.
func channels(_ color: NSColor?) -> [CGFloat]? {
    guard let rgb = color?.usingColorSpace(.sRGB) else { return nil }
    return [rgb.redComponent, rgb.greenComponent, rgb.blueComponent, rgb.alphaComponent]
}

/// The four sRGB channels of a layer's `color`, or nil when there is none.
func channels(_ color: CGColor?) -> [CGFloat]? {
    channels(color.flatMap { NSColor(cgColor: $0) })
}

/// Asserts that `actual` holds the channels `expected` says, each to within a
/// fraction of one step of eight bits.
func assertChannels(
    _ actual: [CGFloat]?,
    _ expected: [CGFloat],
    _ message: String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    guard let actual else {
        return XCTFail("no colour. \(message)", file: file, line: line)
    }
    XCTAssertEqual(actual.count, expected.count, message, file: file, line: line)
    for (channel, wanted) in zip(actual, expected) {
        XCTAssertEqual(channel, wanted, accuracy: 0.002, message, file: file, line: line)
    }
}

#endif
