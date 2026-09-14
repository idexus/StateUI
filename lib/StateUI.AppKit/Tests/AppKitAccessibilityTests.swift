// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

final class AppKitAccessibilityTests: XCTestCase {
    @MainActor
    func testAuthoredIdentityWordsAndHeadingReachTheNativeElement() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        var label = HostPatch(id: .manual("heading"), type: .label)
        label.properties = [
            .text: .string("Visible title"),
            .automationId: .string("semantics.heading"),
            .semanticDescription: .string("Accessible title"),
            .semanticHint: .string("Opens the section"),
            .semanticHeadingLevel: .enumeration(2),
        ]

        renderer.applyForTesting(tree(label))

        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("heading")))
        XCTAssertEqual(native.accessibilityIdentifier(), "semantics.heading")
        XCTAssertEqual(native.accessibilityLabel(), "Accessible title")
        XCTAssertEqual(native.accessibilityHelp(), "Opens the section")
        if #available(macOS 26.0, *) {
            XCTAssertEqual(
                native.accessibilityRole(),
                NSAccessibility.Role(rawValue: "AXHeading"))
        }
        XCTAssertTrue(native.isAccessibilityElement())
    }

    @MainActor
    func testClearingAuthoredSemanticsRestoresTheNativeDefaults() throws {
        let untouched = AppKitColorBoxView()
        let originalIdentifier = untouched.accessibilityIdentifier()
        let originalLabel = untouched.accessibilityLabel()
        let originalHelp = untouched.accessibilityHelp()
        let originalRole = untouched.accessibilityRole()
        let originalElement = untouched.isAccessibilityElement()
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        var box = HostPatch(id: .manual("box"), type: .colorBox)
        box.properties = [
            .automationId: .string("decoration"),
            .semanticDescription: .string("Temporary"),
            .semanticHint: .string("Temporary hint"),
            .semanticHeadingLevel: .enumeration(1),
            .automationIsInAccessibleTree: .bool(true),
        ]
        renderer.applyForTesting(tree(box))
        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("box")))

        var cleared = HostPatch(id: .manual("box"), type: .colorBox)
        cleared.clearedProperties = [
            .automationId,
            .semanticDescription,
            .semanticHint,
            .semanticHeadingLevel,
            .automationIsInAccessibleTree,
        ]
        renderer.applyForTesting(changedTree(cleared))

        XCTAssertEqual(native.accessibilityIdentifier(), originalIdentifier)
        XCTAssertEqual(native.accessibilityLabel(), originalLabel)
        XCTAssertEqual(native.accessibilityHelp(), originalHelp)
        XCTAssertEqual(native.accessibilityRole(), originalRole)
        XCTAssertEqual(native.isAccessibilityElement(), originalElement)
    }

    @MainActor
    func testExplicitExclusionWinsOverWordsAndCanHideAWholeNativeSubtree() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        var child = HostPatch(id: .manual("child"), type: .label)
        child.properties[.text] = .string("Skipped child")
        var stack = HostPatch(id: .manual("stack"), type: .vStack)
        stack.properties = [
            .semanticDescription: .string("Skipped panel"),
            .automationIsInAccessibleTree: .bool(true),
            .automationExcludedWithChildren: .bool(true),
        ]
        stack.children = .arranged([child])

        renderer.applyForTesting(tree(stack))

        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("stack")))
        XCTAssertFalse(native.isAccessibilityElement())
        XCTAssertEqual(native.accessibilityChildren()?.count, 0)
    }

    @MainActor
    func testAViewThatAnswersATapIsPressedByAssistiveTechnology() throws {
        var reports: [Int32] = []
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { id, _ in reports.append(id) })
        defer { renderer.closeForTesting() }
        var caption = HostPatch(id: .manual("caption"), type: .label)
        caption.properties[.text] = .string("Motion")
        caption.events = .replace([.tapped: 301])
        var card = HostPatch(id: .manual("card"), type: .vStack)
        card.properties[.semanticDescription] = .string("Motion sample")
        card.events = .replace([.tapped: 300])
        card.children = .arranged([caption])

        renderer.applyForTesting(tree(card))

        let nativeCard = try XCTUnwrap(renderer.viewForTesting(id: .manual("card")))
        let nativeCaption = try XCTUnwrap(renderer.viewForTesting(id: .manual("caption")))
        XCTAssertTrue(nativeCard.isAccessibilityElement())
        XCTAssertEqual(nativeCard.accessibilityRole(), .button)
        XCTAssertTrue(nativeCard.accessibilityPerformPress())
        XCTAssertTrue(nativeCaption.accessibilityPerformPress())
        XCTAssertEqual(reports, [300, 301])

        var plain = HostPatch(id: .manual("card"), type: .vStack)
        plain.events = .replace([:])
        renderer.applyForTesting(changedTree(plain))

        XCTAssertFalse(nativeCard.accessibilityPerformPress())
        XCTAssertNotEqual(nativeCard.accessibilityRole(), .button)
        XCTAssertEqual(reports, [300, 301])
    }

    @MainActor
    func testAButtonIsAButtonToAssistiveTechnologyWithOrWithoutAuthoredWords() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        var captioned = HostPatch(id: .manual("captioned"), type: .button)
        captioned.properties = [
            .text: .string("Save"),
            .automationId: .string("save"),
        ]
        var described = HostPatch(id: .manual("described"), type: .button)
        described.properties = [
            .icon: .string("favourite.png"),
            .automationId: .string("semantics.described"),
            .semanticDescription: .string("Add to favourites"),
        ]
        var stack = HostPatch(id: .manual("stack"), type: .vStack)
        stack.children = .arranged([captioned, described])

        renderer.applyForTesting(tree(stack))

        // What assistive technology meets is what AppKit presents under the
        // stack - for a button, its cell - not whichever view the host made.
        let stackView = try XCTUnwrap(renderer.viewForTesting(id: .manual("stack")))
        let save = try XCTUnwrap(presented("save", under: stackView))
        XCTAssertEqual(save.role, .button)
        let favourite = try XCTUnwrap(presented("semantics.described", under: stackView))
        XCTAssertEqual(favourite.role, .button)
        XCTAssertEqual(favourite.label, "Add to favourites")
    }

    @MainActor
    func testAWrappedControlCarriesItsWordsOnTheControlItWraps() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        func described(_ identifier: String, _ type: NodeType, _ words: String) -> HostPatch {
            var patch = HostPatch(id: .manual(identifier), type: type)
            patch.properties = [
                .automationId: .string(identifier),
                .semanticDescription: .string(words),
            ]
            return patch
        }
        var stack = HostPatch(id: .manual("stack"), type: .vStack)
        stack.children = .arranged([
            described("picker.size", .picker, "Size"),
            described("entry.name", .textField, "Name"),
            described("editor.notes", .textEditor, "Notes"),
        ])

        renderer.applyForTesting(tree(stack))

        let stackView = try XCTUnwrap(renderer.viewForTesting(id: .manual("stack")))
        let expected: [(identifier: String, role: NSAccessibility.Role, words: String)] = [
            ("picker.size", .popUpButton, "Size"),
            ("entry.name", .textField, "Name"),
            ("editor.notes", .textArea, "Notes"),
        ]
        for control in expected {
            let element = try XCTUnwrap(
                presented(control.identifier, under: stackView), control.identifier)
            XCTAssertEqual(element.role, control.role, control.identifier)
            XCTAssertEqual(element.label, control.words, control.identifier)
        }
    }

    @MainActor
    func testAPasswordFieldKeepsItsWordsWhenItsNativeFieldIsReplaced() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        var entry = HostPatch(id: .manual("entry"), type: .textField)
        entry.properties = [
            .text: .string(""),
            .automationId: .string("entry.password"),
            .semanticDescription: .string("Password"),
        ]
        renderer.applyForTesting(tree(entry))

        var secure = HostPatch(id: .manual("entry"), type: .textField)
        secure.properties[.isPassword] = .bool(true)
        renderer.applyForTesting(changedTree(secure))

        let field = try XCTUnwrap(renderer.viewForTesting(id: .manual("entry")))
        let element = try XCTUnwrap(presented("entry.password", under: field))
        XCTAssertEqual(element.role, .textField)
        XCTAssertEqual(element.label, "Password")
    }

    /// The element AppKit presents to assistive technology under `view` with
    /// this identifier - a view, or the cell a control is presented through -
    /// however deep AppKit nests it.
    @MainActor
    private func presented(
        _ identifier: String,
        under view: NSView
    ) -> (role: NSAccessibility.Role?, label: String?)? {
        for child in view.accessibilityChildren() ?? [] {
            if let cell = child as? NSCell, cell.accessibilityIdentifier() == identifier {
                return (cell.accessibilityRole(), cell.accessibilityLabel())
            }
            if let element = child as? NSView {
                if element.accessibilityIdentifier() == identifier {
                    return (element.accessibilityRole(), element.accessibilityLabel())
                }
                if let found = presented(identifier, under: element) {
                    return found
                }
            }
        }
        return nil
    }
}

#endif
