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
        let untouched = AppKitBoxView()
        let originalIdentifier = untouched.accessibilityIdentifier()
        let originalLabel = untouched.accessibilityLabel()
        let originalHelp = untouched.accessibilityHelp()
        let originalRole = untouched.accessibilityRole()
        let originalElement = untouched.isAccessibilityElement()
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        var box = HostPatch(id: .manual("box"), type: .boxView)
        box.properties = [
            .automationId: .string("decoration"),
            .semanticDescription: .string("Temporary"),
            .semanticHint: .string("Temporary hint"),
            .semanticHeadingLevel: .enumeration(1),
            .automationIsInAccessibleTree: .bool(true),
        ]
        renderer.applyForTesting(tree(box))
        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("box")))

        var cleared = HostPatch(id: .manual("box"), type: .boxView)
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

    private func tree(_ content: HostPatch) -> HostPatch {
        var page = HostPatch(id: .manual("page"), type: .contentPage)
        page.children = .arranged([content])
        var window = HostPatch(id: .manual("window"), type: .window)
        window.children = .arranged([page])
        var scene = HostPatch(id: .manual("scene"), type: .scene)
        scene.children = .arranged([window])
        var application = HostPatch(id: .manual("application"), type: .application)
        application.children = .arranged([scene])
        return application
    }

    private func changedTree(_ content: HostPatch) -> HostPatch {
        var page = HostPatch(id: .manual("page"), type: .contentPage)
        page.children = .changed([content])
        var window = HostPatch(id: .manual("window"), type: .window)
        window.children = .changed([page])
        var scene = HostPatch(id: .manual("scene"), type: .scene)
        scene.children = .changed([window])
        var application = HostPatch(id: .manual("application"), type: .application)
        application.children = .changed([scene])
        return application
    }
}

#endif
