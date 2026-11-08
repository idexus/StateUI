// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WebRegistrations {
    /// The seven shapes: a rectangle, a capsule and an ellipse filling their room, and a line, a path, a polygon and a
    /// polyline drawn from their own geometry - each filled, outlined and placed as the shape tier says.
    static func shapes(_ registry: Registry<WebDOMView>) {
        registry.add(RectangleContract.self, create: { _ in WebShapeView() }) { shape in
            shape.applies(ShapeMembers.corneredMembers, RectangleContract.cornerRadius) { view, values in
                paint(view, values)
                view.draw(.rectangle(BoxArithmetic.clockwise(values[RectangleContract.cornerRadius]), transform: moved(values)))
            }
        }
        registry.add(EllipseContract.self, create: { _ in WebShapeView() }) { shape in
            shape.applies(ShapeMembers.filledMembers) { view, values in
                paint(view, values)
                view.draw(.ellipse(transform: moved(values)))
            }
        }
        registry.add(CapsuleContract.self, create: { _ in WebShapeView() }) { shape in
            shape.applies(ShapeMembers.filledMembers) { view, values in
                paint(view, values)
                view.draw(.rectangle(BoxArithmetic.clockwise(BoxArithmetic.capsule), transform: moved(values)))
            }
        }
        registry.add(LineContract.self, create: { _ in WebShapeView() }) { shape in
            shape.applies(ShapeMembers.members, LineContract.from, LineContract.to) { view, values in
                paint(view, values)
                let from = values[LineContract.from] ?? .zero, to = values[LineContract.to] ?? .zero
                view.draw(authored([0, from.x, from.y, 1, to.x, to.y], evenOdd: false, values))
            }
        }
        registry.add(PathContract.self, create: { _ in WebShapeView() }) { shape in
            shape.applies(ShapeMembers.corneredMembers, PathContract.data) { view, values in
                paint(view, values)
                let curves = HostPath(svg: values[PathContract.data] ?? "")?.arcsAsCubics ?? []
                view.draw(authored(curves.flatMap(\.numbers), evenOdd: false, values))
            }
        }
        registry.add(PolygonContract.self, create: { _ in WebShapeView() }) { shape in
            shape.applies(
                ShapeMembers.corneredMembers, PointsShapeContract.points, PointsShapeContract.fillRule) { view, values in
                paint(view, values)
                view.draw(authored(
                    ShapeArithmetic.curves(through: values[PointsShapeContract.points] ?? [], closed: true).flatMap(\.numbers),
                    evenOdd: (values[PointsShapeContract.fillRule] ?? .evenOdd) == .evenOdd, values))
            }
        }
        registry.add(PolylineContract.self, create: { _ in WebShapeView() }) { shape in
            shape.applies(
                ShapeMembers.corneredMembers, PointsShapeContract.points, PointsShapeContract.fillRule) { view, values in
                paint(view, values)
                view.draw(authored(
                    ShapeArithmetic.curves(through: values[PointsShapeContract.points] ?? [], closed: false).flatMap(\.numbers),
                    evenOdd: (values[PointsShapeContract.fillRule] ?? .evenOdd) == .evenOdd, values))
            }
        }
    }




    private static func paint<Realized: ElementContract>(_ view: WebShapeView, _ values: ElementValues<Realized>) {
        view.paint(
            fill: values[FilledShapeContract.fill]?.propValue,
            stroke: values[ShapeContract.stroke]?.propValue,
            width: values[ShapeContract.lineWidth] ?? 1,
            dashes: values[ShapeContract.dash] ?? [],
            dashOffset: values[ShapeContract.dashPhase] ?? 0,
            cap: values[ShapeContract.lineCap] ?? .flat,
            join: values[CorneredShapeContract.lineJoin] ?? .miter,
            miter: values[CorneredShapeContract.miterLimit] ?? 10)
    }

    /// A geometry of the shape's own, placed by its aspect and moved by its transform.
    private static func authored<Realized: ElementContract>(
        _ commands: [Double], evenOdd: Bool, _ values: ElementValues<Realized>
    ) -> WebShapeView.Geometry {
        .authored(commands, evenOdd: evenOdd, aspect: values[ContentModeElementContract.contentMode] ?? .fit, transform: moved(values))
    }

    /// The shape's own transform, by the host layer's rule.
    private static func moved<Realized: ElementContract>(_ values: ElementValues<Realized>) -> [Double]? {
        ShapeArithmetic.transform(values[ShapeContract.geometryTransform]?.propValue)
    }
}
