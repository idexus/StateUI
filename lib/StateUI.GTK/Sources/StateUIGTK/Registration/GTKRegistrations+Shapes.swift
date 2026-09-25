// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension GTKRegistrations {
    /// The six shapes: a rectangle and an ellipse filling their room, and a line, a path, a polygon and a polyline
    /// drawn from their own geometry - each filled, outlined and placed as the shape tier says.
    static func shapes(_ registry: Registry<GTKView>) {
        registry.add(RectangleContract.self, create: { _ in GTKShapeView() }) { shape in
            shape.applies(shapeMembers + [RectangleContract.cornerRadius]) { view, values in
                paint(view, values)
                view.draw(.rectangle(radii(values[RectangleContract.cornerRadius])))
            }
        }
        registry.add(EllipseContract.self, create: { _ in GTKShapeView() }) { shape in
            shape.applies(shapeMembers) { view, values in
                paint(view, values)
                view.draw(.ellipse)
            }
        }
        registry.add(LineContract.self, create: { _ in GTKShapeView() }) { shape in
            shape.applies(shapeMembers + [LineContract.x1, LineContract.y1, LineContract.x2, LineContract.y2]) {
                view, values in
                paint(view, values)
                let from = [values[LineContract.x1] ?? 0, values[LineContract.y1] ?? 0]
                let to = [values[LineContract.x2] ?? 0, values[LineContract.y2] ?? 0]
                view.draw(authored([0] + from + [1] + to, evenOdd: false, values))
            }
        }
        registry.add(PathContract.self, create: { _ in GTKShapeView() }) { shape in
            shape.applies(shapeMembers + [PathContract.data]) { view, values in
                paint(view, values)
                let curves = HostPath(svg: values[PathContract.data] ?? "")?.arcsAsCubics ?? []
                view.draw(authored(curves.flatMap(\.numbers), evenOdd: false, values))
            }
        }
        registry.add(PolygonContract.self, create: { _ in GTKShapeView() }) { shape in
            shape.applies(shapeMembers + [PolygonContract.points, PolygonContract.fillRule]) { view, values in
                paint(view, values)
                view.draw(authored(
                    polyline(values[PolygonContract.points] ?? [], closed: true),
                    evenOdd: (values[PolygonContract.fillRule] ?? .evenOdd) == .evenOdd, values))
            }
        }
        registry.add(PolylineContract.self, create: { _ in GTKShapeView() }) { shape in
            shape.applies(shapeMembers + [PolylineContract.points, PolylineContract.fillRule]) { view, values in
                paint(view, values)
                view.draw(authored(
                    polyline(values[PolylineContract.points] ?? [], closed: false),
                    evenOdd: (values[PolylineContract.fillRule] ?? .evenOdd) == .evenOdd, values))
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

    private static func paint<Realized: ElementContract>(_ view: GTKShapeView, _ values: ElementValues<Realized>) {
        view.paint(
            fill: GTKBrush(values[ShapeContract.fill]?.propValue),
            stroke: GTKBrush(values[ShapeContract.stroke]?.propValue),
            width: values[ShapeContract.strokeWidth] ?? 1,
            dashes: values[ShapeContract.strokeDashPattern] ?? [],
            dashOffset: values[ShapeContract.strokeDashOffset] ?? 0,
            cap: values[ShapeContract.strokeLineCap] ?? .flat,
            join: values[ShapeContract.strokeLineJoin] ?? .miter,
            miter: values[ShapeContract.strokeMiterLimit] ?? 10)
    }

    /// A geometry of the shape's own, placed by its aspect and moved by its transform.
    private static func authored<Realized: ElementContract>(
        _ commands: [Double], evenOdd: Bool, _ values: ElementValues<Realized>
    ) -> GTKShapeView.Geometry {
        let transform = values[ShapeContract.renderTransform]?.propValue.values?.compactMap(\.number)
        return .authored(
            commands, evenOdd: evenOdd, aspect: values[ShapeContract.aspect] ?? .fit,
            transform: transform.flatMap { $0.count == 6 && $0.allSatisfy(\.isFinite) ? $0 : nil })
    }

    /// A rectangle's corners, clockwise from the top left.
    private static func radii(_ corners: CornerRadius?) -> [Double] {
        switch corners {
        case .uniform(let radius): [radius, radius, radius, radius]
        case .corners(let topLeft, let topRight, let bottomLeft, let bottomRight):
            [topLeft, topRight, bottomRight, bottomLeft]
        case nil: [0, 0, 0, 0]
        }
    }

    /// Points joined by lines, and closed where the shape is.
    private static func polyline(_ points: [Point], closed: Bool) -> [Double] {
        let finite = points.filter { $0.x.isFinite && $0.y.isFinite }
        guard let first = finite.first else { return [] }
        return [0, first.x, first.y] + finite.dropFirst().flatMap { [1, $0.x, $0.y] } + (closed ? [4] : [])
    }
}
