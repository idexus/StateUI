// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import XCTest

/// The shapes, realized through the registry: six elements
/// over one native view, each registration knowing only the geometry it is,
/// and the stroke, fill and transform they share coming from the one tier they
/// all wear.
///
/// What a shape DRAWS is held to `AppKitShapeViewTests`, whose host-patch tests
/// drive these same registered views.
@MainActor
final class AppKitShapeRegistrationTests: XCTestCase {
    /// Every shape is registered, each with the members of its own geometry.
    @MainActor
    func testTheRegistryRealizesEveryShape() {
        let realization = AppKitRegistrations.registry.realization

        XCTAssertTrue(realization.elements.isSuperset(of: [
            "Rectangle", "Capsule", "Ellipse", "Line", "Path", "Polygon", "Polyline",
        ]))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "Rectangle", owner: "Rectangle", member: "cornerRadius")))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "Line", owner: "Line", member: "x1")))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "Path", owner: "Path", member: "data")))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "Polygon", owner: "Polygon", member: "fillRule")))
    }

    /// What the shapes SHARE is recorded on every one of them, from the single
    /// tier they wear; a fill only on a shape enclosing an area, and a line,
    /// which encloses none, claims none.
    @MainActor
    func testTheSharedStrokeAndFillAreRecordedOnEveryShape() {
        let realization = AppKitRegistrations.registry.realization

        for shape in ["Rectangle", "Capsule", "Ellipse", "Line", "Path", "Polygon", "Polyline"] {
            XCTAssertTrue(
                realization.members.contains(
                    HostRealizedMember(element: shape, owner: "Shape", member: "stroke")),
                "\(shape) draws the stroke its tier declares")
            XCTAssertEqual(
                realization.members.contains(
                    HostRealizedMember(element: shape, owner: "FilledShape", member: "fill")),
                shape != "Line",
                "\(shape) draws the fill its tier declares")
        }
    }

    /// An ellipse has no geometry of its own to describe, and is registered all
    /// the same: the tier it wears is the whole of what it takes.
    /// A figure made of a blur stands AppKit's effect view lowest, cut to the figure, its outline drawn over it; a
    /// paint again takes both away.
    @MainActor
    func testAFigureMadeOfABlurStandsAppKitsEffectUnderItsOutline() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var capsule = HostPatch(id: .manual("capsule"), type: .capsule)
        capsule.properties[.fill] = Material.blur(.thin).propValue
        capsule.properties[.stroke] = Brush.solidColor(Color(hex: 0xFFFFFF)).propValue
        capsule.properties[.width] = .number(80)
        capsule.properties[.height] = .number(30)
        renderer.applyForTesting(tree(capsule))
        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("capsule")) as? AppKitShapeView)
        native.setFrameSize(NSSize(width: 80, height: 30))

        let surface = try XCTUnwrap(native.surface as? AppKitMaterialView, "the blur is AppKit's own effect view")
        XCTAssertEqual(native.subviews.first, surface, "lowest in the figure")
        XCTAssertTrue(native.subviews.last is AppKitShapeOutline, "the outline over it")
        let cut = try XCTUnwrap(surface.layer?.mask as? CAShapeLayer, "cut to the figure")
        XCTAssertFalse(try XCTUnwrap(cut.path).boundingBox.isEmpty)

        capsule.properties[.fill] = Material.color(Color(hex: 0xFF0000)).propValue
        renderer.applyForTesting(tree(capsule))
        XCTAssertNil(native.surface, "a paint stands no surface")
        XCTAssertTrue(native.subviews.isEmpty, "and no outline over one")
    }

    @MainActor
    func testAnEllipseIsMadeAndDrawnFromItsTierAlone() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var ellipse = HostPatch(id: .manual("ellipse"), type: .ellipse)
        ellipse.properties[.fill] = Material.color(Color(red: 51, green: 102, blue: 153)).propValue
        ellipse.properties[.stroke] = Brush.solidColor(Color(hex: 0x000000)).propValue
        ellipse.properties[.lineWidth] = .number(3)
        ellipse.properties[.dash] = .numbers([2, 1])
        renderer.applyForTesting(tree(ellipse))

        let native = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("ellipse")) as? AppKitShapeView)

        XCTAssertNotNil(native.fillForTesting.color, "the fill reaches the ellipse as the material its contract declares")
        XCTAssertEqual(native.dashPatternForTesting, [6, 3], "a dash is in stroke widths")
        XCTAssertFalse(
            native.pathForTesting(in: NSRect(x: 0, y: 0, width: 40, height: 20)).isEmpty,
            "the ellipse draws a path in the room it is given")
    }
}
#endif
