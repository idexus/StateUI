// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension WinUIRegistrations {
    /// The six shapes: a rectangle and an ellipse filling their room, and a line, a path, a polygon and a polyline
    /// drawn from their own geometry - each filled, outlined and placed as the shape tier says.
    static func shapes(_ registry: Registry<WinUIView>) {
        registry.add(RectangleContract.self, create: { _ in WinUIPathView() }) { shape in
            shape.applies(shapeMembers + [RectangleContract.cornerRadius]) { view, values in
                paint(view, values)
                view.draw(.rectangle(
                    BoxArithmetic.clockwise(values[RectangleContract.cornerRadius]), transform: moved(values)))
            }
        }
        registry.add(EllipseContract.self, create: { _ in WinUIPathView() }) { shape in
            shape.applies(shapeMembers) { view, values in
                paint(view, values)
                view.draw(.ellipse(transform: moved(values)))
            }
        }
        registry.add(LineContract.self, create: { _ in WinUIPathView() }) { shape in
            shape.applies(shapeMembers + [LineContract.x1, LineContract.y1, LineContract.x2, LineContract.y2]) {
                view, values in
                paint(view, values)
                let from = [values[LineContract.x1] ?? 0, values[LineContract.y1] ?? 0]
                let to = [values[LineContract.x2] ?? 0, values[LineContract.y2] ?? 0]
                view.draw(authored([0] + from + [1] + to, evenOdd: false, values))
            }
        }
        registry.add(PathContract.self, create: { _ in WinUIPathView() }) { shape in
            shape.applies(shapeMembers + [PathContract.data]) { view, values in
                paint(view, values)
                let curves = HostPath(svg: values[PathContract.data] ?? "")?.arcsAsCubics ?? []
                view.draw(authored(curves.flatMap(\.numbers), evenOdd: false, values))
            }
        }
        registry.add(PolygonContract.self, create: { _ in WinUIPathView() }) { shape in
            shape.applies(shapeMembers + [PolygonContract.points, PolygonContract.fillRule]) { view, values in
                paint(view, values)
                view.draw(authored(
                    ShapeArithmetic.commands(through: values[PolygonContract.points] ?? [], closed: true),
                    evenOdd: (values[PolygonContract.fillRule] ?? .evenOdd) == .evenOdd, values))
            }
        }
        registry.add(PolylineContract.self, create: { _ in WinUIPathView() }) { shape in
            shape.applies(shapeMembers + [PolylineContract.points, PolylineContract.fillRule]) { view, values in
                paint(view, values)
                view.draw(authored(
                    ShapeArithmetic.commands(through: values[PolylineContract.points] ?? [], closed: false),
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

    private static func paint<Realized: ElementContract>(_ view: WinUIPathView, _ values: ElementValues<Realized>) {
        view.paint(
            fill: WinUIBrush(values[ShapeContract.fill]?.propValue),
            stroke: WinUIBrush(values[ShapeContract.stroke]?.propValue),
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
    ) -> WinUIPathView.Geometry {
        .authored(commands, evenOdd: evenOdd, aspect: values[ShapeContract.aspect] ?? .fit, transform: moved(values))
    }

    /// The shape's transform, as the six numbers of its matrix; nil for none.
    private static func moved<Realized: ElementContract>(_ values: ElementValues<Realized>) -> [Double]? {
        values[ShapeContract.renderTransform]?.propValue.values?.compactMap(\.number)
    }
}
