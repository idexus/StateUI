// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AndroidRegistrations {
    /// The six shapes: a rectangle and an ellipse filling their room, and a line, a path, a polygon and a
    /// polyline drawn from their own geometry - each filled, outlined and placed as the shape tier says.
    static func shapes(_ registry: Registry<AndroidView>) {
        registry.add(RectangleContract.self, create: { _ in AndroidShapeView() }) { shape in
            shape.applies(shapeMembers + [RectangleContract.cornerRadius]) { view, values in
                draw(view, values, .rectangle(values[RectangleContract.cornerRadius]))
            }
        }
        registry.add(EllipseContract.self, create: { _ in AndroidShapeView() }) { shape in
            shape.applies(shapeMembers) { view, values in draw(view, values, .ellipse) }
        }
        registry.add(LineContract.self, create: { _ in AndroidShapeView() }) { shape in
            shape.applies(shapeMembers + [LineContract.x1, LineContract.y1, LineContract.x2, LineContract.y2]) {
                view, values in
                draw(view, values, .line(
                    Point(values[LineContract.x1] ?? 0, values[LineContract.y1] ?? 0),
                    Point(values[LineContract.x2] ?? 0, values[LineContract.y2] ?? 0)))
            }
        }
        registry.add(PathContract.self, create: { _ in AndroidShapeView() }) { shape in
            shape.applies(shapeMembers + [PathContract.data]) { view, values in
                draw(view, values, .path(values[PathContract.data] ?? ""))
            }
        }
        registry.add(PolygonContract.self, create: { _ in AndroidShapeView() }) { shape in
            shape.applies(shapeMembers + [PolygonContract.points, PolygonContract.fillRule]) { view, values in
                draw(view, values, .points(
                    values[PolygonContract.points] ?? [], closed: true,
                    evenOdd: (values[PolygonContract.fillRule] ?? .evenOdd) == .evenOdd))
            }
        }
        registry.add(PolylineContract.self, create: { _ in AndroidShapeView() }) { shape in
            shape.applies(shapeMembers + [PolylineContract.points, PolylineContract.fillRule]) { view, values in
                draw(view, values, .points(
                    values[PolylineContract.points] ?? [], closed: false,
                    evenOdd: (values[PolylineContract.fillRule] ?? .evenOdd) == .evenOdd))
            }
        }
    }

    /// What every shape takes whole.
    private static let shapeMembers: [any ContractMember] = [
        ShapeContract.fill, ShapeContract.stroke, ShapeContract.strokeWidth,
        ShapeContract.strokeDashPattern, ShapeContract.strokeDashOffset,
        ShapeContract.strokeLineCap, ShapeContract.strokeLineJoin, ShapeContract.strokeMiterLimit,
        ShapeContract.aspect, ShapeContract.renderTransform,
    ]

    private static func draw<Realized: ElementContract>(
        _ view: AndroidShapeView, _ values: ElementValues<Realized>, _ geometry: AndroidShapeView.Geometry
    ) {
        let transform = values[ShapeContract.renderTransform]?.propValue.values?.compactMap(\.number)
        view.draw(
            geometry,
            fill: values[ShapeContract.fill]?.propValue,
            stroke: values[ShapeContract.stroke]?.propValue,
            strokeWidth: values[ShapeContract.strokeWidth] ?? 1,
            dashes: values[ShapeContract.strokeDashPattern] ?? [],
            dashOffset: values[ShapeContract.strokeDashOffset] ?? 0,
            cap: values[ShapeContract.strokeLineCap]?.rawValue ?? 0,
            join: values[ShapeContract.strokeLineJoin]?.rawValue ?? 0,
            miterLimit: values[ShapeContract.strokeMiterLimit] ?? 10,
            aspect: values[ShapeContract.aspect]?.rawValue ?? 0,
            transform: transform.flatMap { $0.count == 6 && $0.allSatisfy(\.isFinite) ? $0 : nil })
    }
}
