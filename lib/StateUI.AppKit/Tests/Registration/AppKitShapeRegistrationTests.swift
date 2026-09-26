// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import XCTest

/// The shapes and the colour box, realized through the registry: six elements
/// over one native view, each registration knowing only the geometry it is,
/// and the stroke, fill and transform they share coming from the one tier they
/// all wear.
///
/// What a shape DRAWS is held to `AppKitShapeViewTests`, whose host-patch tests
/// drive these same registered views.
final class AppKitShapeRegistrationTests: XCTestCase {
    /// Every shape is registered, each with the members of its own geometry.
    @MainActor
    func testTheRegistryRealizesEveryShape() {
        let realization = AppKitRegistrations.registry.realization

        XCTAssertTrue(realization.elements.isSuperset(of: [
            "Rectangle", "Ellipse", "Line", "Path", "Polygon", "Polyline", "ColorBox",
        ]))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "Rectangle", owner: "Rectangle", member: "cornerRadius")))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "Line", owner: "Line", member: "x1")))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "Path", owner: "Path", member: "data")))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "Polygon", owner: "Polygon", member: "fillRule")))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "ColorBox", owner: "ColorBox", member: "color")))
    }

    /// What the shapes SHARE is recorded on every one of them, from the single
    /// tier they wear - and an element that wears no such tier claims none of
    /// it.
    @MainActor
    func testTheSharedStrokeAndFillAreRecordedOnEveryShape() {
        let realization = AppKitRegistrations.registry.realization

        for shape in ["Rectangle", "Ellipse", "Line", "Path", "Polygon", "Polyline"] {
            XCTAssertTrue(
                realization.members.contains(
                    HostRealizedMember(element: shape, owner: "Shape", member: "stroke")),
                "\(shape) draws the stroke its tier declares")
            XCTAssertTrue(
                realization.members.contains(
                    HostRealizedMember(element: shape, owner: "Shape", member: "fill")),
                "\(shape) draws the fill its tier declares")
        }

        XCTAssertFalse(
            realization.members.contains(
                HostRealizedMember(element: "ColorBox", owner: "Shape", member: "stroke")),
            "a colour box wears no Shape, and claims nothing of it")
    }

    /// An ellipse has no geometry of its own to describe, and is registered all
    /// the same: the tier it wears is the whole of what it takes.
    @MainActor
    func testAnEllipseIsMadeAndDrawnFromItsTierAlone() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var ellipse = HostPatch(id: .manual("ellipse"), type: .ellipse)
        ellipse.properties[.fill] = .color(red: 51, green: 102, blue: 153, alpha: 255)
        ellipse.properties[.strokeWidth] = .number(3)
        ellipse.properties[.strokeDashPattern] = .numbers([2, 1])
        renderer.applyForTesting(tree(ellipse))

        let native = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("ellipse")) as? AppKitShapeView)

        XCTAssertEqual(native.dashPatternForTesting, [6, 3], "a dash is in stroke widths")
        XCTAssertFalse(
            native.pathForTesting(in: NSRect(x: 0, y: 0, width: 40, height: 20)).isEmpty,
            "the ellipse draws a path in the room it is given")
    }
}
#endif
