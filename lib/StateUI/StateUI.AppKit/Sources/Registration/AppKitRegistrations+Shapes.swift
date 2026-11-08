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
    /// own thing: two colors and a radius.
    static func shapes(_ registry: Registry<NSView>) {
        registry.add(RectangleContract.self, create: { _ in AppKitShapeView(kind: .rectangle) }) { shape in
            shape.applies(ShapeMembers.corneredMembers, RectangleContract.cornerRadius) { view, values in
                Self.draw(view, values, .rectangle(BoxArithmetic.clockwise(values[RectangleContract.cornerRadius])))
            }
        }

        registry.add(EllipseContract.self, create: { _ in AppKitShapeView(kind: .ellipse) }) { shape in
            shape.applies(ShapeMembers.filledMembers) { view, values in
                Self.draw(view, values, .ellipse)
            }
        }

        registry.add(CapsuleContract.self, create: { _ in AppKitShapeView(kind: .rectangle) }) { shape in
            shape.applies(ShapeMembers.filledMembers) { view, values in
                Self.draw(view, values, .rectangle(BoxArithmetic.clockwise(BoxArithmetic.capsule)))
            }
        }

        registry.add(LineContract.self, create: { _ in AppKitShapeView(kind: .line) }) { shape in
            shape.applies(ShapeMembers.members, LineContract.from, LineContract.to) { view, values in
                let from = values[LineContract.from] ?? .zero, to = values[LineContract.to] ?? .zero
                Self.draw(view, values, .line(
                    x1: CGFloat(from.x), y1: CGFloat(from.y), x2: CGFloat(to.x), y2: CGFloat(to.y)))
            }
        }

        registry.add(PathContract.self, create: { _ in AppKitShapeView(kind: .path) }) { shape in
            shape.applies(ShapeMembers.corneredMembers, PathContract.data) { view, values in
                Self.draw(view, values, .path(values[PathContract.data] ?? ""))
            }
        }

        registry.add(PolygonContract.self, create: { _ in AppKitShapeView(kind: .polygon) }) { shape in
            shape.applies(
                ShapeMembers.corneredMembers, PointsShapeContract.points, PointsShapeContract.fillRule) { view, values in
                Self.draw(view, values, .points(
                    values[PointsShapeContract.points]?.propValue.numbers ?? [],
                    fillRule: values[PointsShapeContract.fillRule]?.rawValue ?? 0))
            }
        }

        registry.add(PolylineContract.self, create: { _ in AppKitShapeView(kind: .polyline) }) { shape in
            shape.applies(
                ShapeMembers.corneredMembers, PointsShapeContract.points, PointsShapeContract.fillRule) { view, values in
                Self.draw(view, values, .points(
                    values[PointsShapeContract.points]?.propValue.numbers ?? [],
                    fillRule: values[PointsShapeContract.fillRule]?.rawValue ?? 0))
            }
        }
    }




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
            aspect: values[ContentModeElementContract.contentMode] ?? .fit,
            geometryTransform: Self.transform(values),
            geometry: geometry)
    }
}

#endif
