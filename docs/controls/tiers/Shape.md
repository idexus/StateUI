<!-- Rendered by ControlDictionaryTests from the contracts and the hosts' declarations of what they realize: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Shape

What every drawn shape has: what fills it, the line around it, how it fits its room, and a transform of its own drawing.

Wears: [View](View.md)

Worn by: [Ellipse](../Ellipse.md) · [Line](../Line.md) · [Path](../Path.md) · [Polygon](../Polygon.md) · [Polyline](../Polyline.md) · [Rectangle](../Rectangle.md)

Declared in `lib/StateUI/Sources/Contracts/Tiers/ShapeContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `aspect` | property | `Aspect` | native |
| `fill` | property | `Brush` | stateUI |
| `renderTransform` | property | `ViewTransform` | native |
| `stroke` | property | `Brush` | stateUI |
| `strokeDashOffset` | property | `Double` | stateUI |
| `strokeDashPattern` | property | `[Double]` | stateUI |
| `strokeLineCap` | property | `LineCap` | stateUI |
| `strokeLineJoin` | property | `LineJoin` | stateUI |
| `strokeMiterLimit` | property | `Double` | stateUI |
| `strokeWidth` | property | `Double` | stateUI |
