<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# Shape

What every drawn shape has: the line along it, how it fits its room, and a transform of its own drawing.

```swift
Line()
    .x2(120)
    .stroke(.black)
    .lineWidth(2)
    .dash([4, 2])
    .lineCap(.round)
```

Wears: [View](View.md)

Worn by: [Capsule](../Capsule.md) · [Ellipse](../Ellipse.md) · [Line](../Line.md) · [Path](../Path.md) · [Polygon](../Polygon.md) · [Polyline](../Polyline.md) · [Rectangle](../Rectangle.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Tiers/ShapeContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `contentMode` | property | `ContentMode` | native |
| `geometryTransform` | property | `ViewTransform` | native |
| `stroke` | property | `Brush` | stateUI |
| `dashPhase` | property | `Double` | stateUI |
| `dash` | property | `[Double]` | stateUI |
| `lineCap` | property | `LineCap` | stateUI |
| `lineWidth` | property | `Double` | stateUI |
