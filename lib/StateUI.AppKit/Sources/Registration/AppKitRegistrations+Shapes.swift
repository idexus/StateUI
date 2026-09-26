// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AppKitRegistrations {
    /// The shapes and the box they are drawn beside. Six elements share one
    /// native view and one tier - `ShapeContract` carries the stroke, the fill
    /// and the transform, and each element adds only the geometry it is: a
    /// radius, four coordinates, a path's data, a run of points. The box is its
    /// own thing: two colours and a radius.
    static func shapes(_ registry: Registry<NSView>) {
        registry.add(RectangleContract.self, create: { _ in AppKitShapeView(kind: .rectangle) }) { shape in
            shape.applies(Self.shapeMembers + [RectangleContract.cornerRadius]) { view, values in
                Self.draw(view, values, .rectangle(
                    AppKitCornerRadii(values[RectangleContract.cornerRadius]?.propValue)))
            }
        }

        registry.add(EllipseContract.self, create: { _ in AppKitShapeView(kind: .ellipse) }) { shape in
            shape.applies(Self.shapeMembers) { view, values in
                Self.draw(view, values, .ellipse)
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
            shape.applies(Self.shapeMembers + [PathContract.data]) { view, values in
                Self.draw(view, values, .path(values[PathContract.data] ?? ""))
            }
        }

        registry.add(PolygonContract.self, create: { _ in AppKitShapeView(kind: .polygon) }) { shape in
            shape.applies(Self.shapeMembers + [PolygonContract.points, PolygonContract.fillRule]) { view, values in
                Self.draw(view, values, .points(
                    values[PolygonContract.points]?.propValue.numbers ?? [],
                    fillRule: values[PolygonContract.fillRule]?.rawValue ?? 0))
            }
        }

        registry.add(PolylineContract.self, create: { _ in AppKitShapeView(kind: .polyline) }) { shape in
            shape.applies(Self.shapeMembers + [PolylineContract.points, PolylineContract.fillRule]) { view, values in
                Self.draw(view, values, .points(
                    values[PolylineContract.points]?.propValue.numbers ?? [],
                    fillRule: values[PolylineContract.fillRule]?.rawValue ?? 0))
            }
        }

        registry.add(ColorBoxContract.self, create: { _ in AppKitColorBoxView() }) { box in
            box.applies([
                ColorBoxContract.color, ColorBoxContract.cornerRadius, VisualElementContract.background,
            ]) { view, values in
                view.apply(
                    background: values[VisualElementContract.background].flatMap { nsColor($0.propValue) },
                    fill: values[ColorBoxContract.color].flatMap { nsColor($0.propValue) },
                    cornerRadius: values[ColorBoxContract.cornerRadius]?.propValue)
            }
        }
    }

    /// What every shape wears, whatever shape it is.
    private static let shapeMembers: [any ContractMember] = [
        ShapeContract.fill, ShapeContract.stroke, ShapeContract.strokeWidth,
        ShapeContract.strokeDashPattern, ShapeContract.strokeDashOffset,
        ShapeContract.strokeLineCap, ShapeContract.strokeLineJoin, ShapeContract.strokeMiterLimit,
        ShapeContract.aspect, ShapeContract.renderTransform,
    ]

    /// The stroke, the fill and the transform every shape draws with, around
    /// the one geometry it is.
    private static func draw<Realized: ElementContract>(
        _ view: AppKitShapeView,
        _ values: ElementValues<Realized>,
        _ geometry: AppKitShapeGeometry
    ) {
        view.apply(
            fill: values[ShapeContract.fill]?.propValue,
            stroke: values[ShapeContract.stroke]?.propValue,
            strokeWidth: values[ShapeContract.strokeWidth] ?? 1,
            dash: values[ShapeContract.strokeDashPattern] ?? [],
            dashOffset: values[ShapeContract.strokeDashOffset] ?? 0,
            lineCap: values[ShapeContract.strokeLineCap]?.rawValue ?? 0,
            lineJoin: values[ShapeContract.strokeLineJoin]?.rawValue ?? 0,
            miterLimit: values[ShapeContract.strokeMiterLimit] ?? 10,
            aspect: values[ShapeContract.aspect]?.rawValue ?? 0,
            renderTransform: Self.transform(values),
            geometry: geometry)
    }
}

#endif
