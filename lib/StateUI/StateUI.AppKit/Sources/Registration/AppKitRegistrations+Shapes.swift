// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AppKitRegistrations {
    /// The shapes and the box they are drawn beside. Seven elements share one
    /// native view and one tier - `ShapeContract` carries the stroke, the fill
    /// and the transform, and each element adds only the geometry it is: a
    /// radius, four coordinates, a path's data, a run of points. The box is its
    /// own thing: two colours and a radius.
    static func shapes(_ registry: Registry<NSView>) {
        registry.add(RectangleContract.self, create: { _ in AppKitShapeView(kind: .rectangle) }) { shape in
            shape.applies(Self.corneredShapeMembers + [RectangleContract.cornerRadius]) { view, values in
                Self.draw(view, values, .rectangle(BoxArithmetic.clockwise(values[RectangleContract.cornerRadius])))
            }
        }

        registry.add(EllipseContract.self, create: { _ in AppKitShapeView(kind: .ellipse) }) { shape in
            shape.applies(Self.filledShapeMembers) { view, values in
                Self.draw(view, values, .ellipse)
            }
        }

        registry.add(CapsuleContract.self, create: { _ in AppKitShapeView(kind: .rectangle) }) { shape in
            shape.applies(Self.filledShapeMembers) { view, values in
                Self.draw(view, values, .rectangle(BoxArithmetic.clockwise(BoxArithmetic.capsule)))
            }
        }

        registry.add(LineContract.self, create: { _ in AppKitShapeView(kind: .line) }) { shape in
            shape.applies(Self.shapeMembers + [
                LineContract.x1, LineContract.y1, LineContract.x2, LineContract.y2,
            ]) { view, values in
                Self.draw(view, values, .line(
                    x1: CGFloat(values[LineContract.x1] ?? 0),
                    y1: CGFloat(values[LineContract.y1] ?? 0),
                    x2: CGFloat(values[LineContract.x2] ?? 0),
                    y2: CGFloat(values[LineContract.y2] ?? 0)))
            }
        }

        registry.add(PathContract.self, create: { _ in AppKitShapeView(kind: .path) }) { shape in
            shape.applies(Self.corneredShapeMembers + [PathContract.data]) { view, values in
                Self.draw(view, values, .path(values[PathContract.data] ?? ""))
            }
        }

        registry.add(PolygonContract.self, create: { _ in AppKitShapeView(kind: .polygon) }) { shape in
            shape.applies(Self.corneredShapeMembers + [PolygonContract.points, PolygonContract.fillRule]) { view, values in
                Self.draw(view, values, .points(
                    values[PolygonContract.points]?.propValue.numbers ?? [],
                    fillRule: values[PolygonContract.fillRule]?.rawValue ?? 0))
            }
        }

        registry.add(PolylineContract.self, create: { _ in AppKitShapeView(kind: .polyline) }) { shape in
            shape.applies(Self.corneredShapeMembers + [PolylineContract.points, PolylineContract.fillRule]) { view, values in
                Self.draw(view, values, .points(
                    values[PolylineContract.points]?.propValue.numbers ?? [],
                    fillRule: values[PolylineContract.fillRule]?.rawValue ?? 0))
            }
        }
    }

    /// What every shape wears, whatever shape it is.
    private static let shapeMembers: [any ContractMember] = [
        ShapeContract.stroke, ShapeContract.lineWidth,
        ShapeContract.dash, ShapeContract.dashPhase,
        ShapeContract.lineCap,
        ShapeContract.contentMode, ShapeContract.geometryTransform,
    ]

    /// What a shape enclosing an area wears: its fill besides.
    private static let filledShapeMembers: [any ContractMember] = shapeMembers + [FilledShapeContract.fill]

    /// What a shape turning corners wears: how they join, and how far a sharp one reaches, besides.
    private static let corneredShapeMembers: [any ContractMember] = filledShapeMembers + [
        CorneredShapeContract.lineJoin, CorneredShapeContract.miterLimit,
    ]

    /// The stroke, the fill and the transform every shape draws with, around
    /// the one geometry it is.
    private static func draw<Realized: ElementContract>(
        _ view: AppKitShapeView,
        _ values: ElementValues<Realized>,
        _ geometry: AppKitShapeGeometry
    ) {
        view.apply(
            fill: values[FilledShapeContract.fill]?.propValue,
            stroke: values[ShapeContract.stroke]?.propValue,
            lineWidth: values[ShapeContract.lineWidth],
            dash: values[ShapeContract.dash] ?? [],
            dashOffset: values[ShapeContract.dashPhase] ?? 0,
            lineCap: values[ShapeContract.lineCap]?.rawValue ?? 0,
            lineJoin: values[CorneredShapeContract.lineJoin]?.rawValue ?? 0,
            miterLimit: values[CorneredShapeContract.miterLimit] ?? 10,
            aspect: values[ShapeContract.contentMode] ?? .fit,
            geometryTransform: Self.transform(values),
            geometry: geometry)
    }
}

#endif
