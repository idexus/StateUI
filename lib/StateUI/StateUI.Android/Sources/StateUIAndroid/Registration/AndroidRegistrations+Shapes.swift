// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AndroidRegistrations {
    /// The seven shapes: a rectangle, a capsule and an ellipse filling their room, and a line, a path, a polygon and a
    /// polyline drawn from their own geometry - each filled, outlined and placed as the shape tier says.
    static func shapes(_ registry: Registry<AndroidView>) {
        registry.add(RectangleContract.self, create: { _ in AndroidShapeView() }) { shape in
            shape.applies(ShapeMembers.corneredMembers, RectangleContract.cornerRadius) { view, values in
                draw(view, values, .rectangle(values[RectangleContract.cornerRadius]))
            }
        }
        registry.add(EllipseContract.self, create: { _ in AndroidShapeView() }) { shape in
            shape.applies(ShapeMembers.filledMembers) { view, values in draw(view, values, .ellipse) }
        }
        registry.add(CapsuleContract.self, create: { _ in AndroidShapeView() }) { shape in
            shape.applies(
                ShapeMembers.filledMembers) { view, values in draw(view, values, .rectangle(BoxArithmetic.capsule)) }
        }
        registry.add(LineContract.self, create: { _ in AndroidShapeView() }) { shape in
            shape.applies(ShapeMembers.members, LineContract.from, LineContract.to) { view, values in
                draw(view, values, .line(values[LineContract.from] ?? .zero, values[LineContract.to] ?? .zero))
            }
        }
        registry.add(PathContract.self, create: { _ in AndroidShapeView() }) { shape in
            shape.applies(ShapeMembers.corneredMembers, PathContract.data) { view, values in
                draw(view, values, .path(values[PathContract.data] ?? ""))
            }
        }
        registry.add(PolygonContract.self, create: { _ in AndroidShapeView() }) { shape in
            shape.applies(
                ShapeMembers.corneredMembers, PointsShapeContract.points, PointsShapeContract.fillRule) { view, values in
                draw(view, values, .points(
                    values[PointsShapeContract.points] ?? [], closed: true,
                    evenOdd: (values[PointsShapeContract.fillRule] ?? .evenOdd) == .evenOdd))
            }
        }
        registry.add(PolylineContract.self, create: { _ in AndroidShapeView() }) { shape in
            shape.applies(
                ShapeMembers.corneredMembers, PointsShapeContract.points, PointsShapeContract.fillRule) { view, values in
                draw(view, values, .points(
                    values[PointsShapeContract.points] ?? [], closed: false,
                    evenOdd: (values[PointsShapeContract.fillRule] ?? .evenOdd) == .evenOdd))
            }
        }
    }




    private static func draw<Realized: ElementContract>(
        _ view: AndroidShapeView, _ values: ElementValues<Realized>, _ geometry: AndroidShapeView.Geometry
    ) {
        let transform = values[ShapeContract.geometryTransform]?.propValue.values?.compactMap(\.number)
        view.draw(
            geometry,
            fill: HostMaterial(values[FilledShapeContract.fill]?.propValue).painted,
            stroke: values[ShapeContract.stroke]?.propValue,
            lineWidth: values[ShapeContract.lineWidth] ?? 1,
            dashes: values[ShapeContract.dash] ?? [],
            dashOffset: values[ShapeContract.dashPhase] ?? 0,
            cap: values[ShapeContract.lineCap]?.rawValue ?? 0,
            join: values[CorneredShapeContract.lineJoin]?.rawValue ?? 0,
            miterLimit: values[CorneredShapeContract.miterLimit] ?? 10,
            aspect: values[ContentModeElementContract.contentMode]?.rawValue ?? 0,
            transform: transform.flatMap { $0.count == 6 && $0.allSatisfy(\.isFinite) ? $0 : nil })
    }
}
