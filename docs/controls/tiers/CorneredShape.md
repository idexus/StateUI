<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# CorneredShape

A shape whose outline turns corners - a rectangle, a polygon, a polyline, a path; neither a line nor an ellipse.

```swift
Polygon([Point(0, 40), Point(20, 0), Point(40, 40)])
    .stroke(.black)
    .lineWidth(6)
    .lineJoin(.round)
```

Wears: [Shape](Shape.md)

Worn by: [Path](../Path.md) · [Polygon](../Polygon.md) · [Polyline](../Polyline.md) · [Rectangle](../Rectangle.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Tiers/CorneredShapeContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `lineJoin` | property | `LineJoin` | stateUI |
| `miterLimit` | property | `Double` | stateUI |
