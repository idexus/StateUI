<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# PointsShape

What a shape drawn through a list of points has: the points, and which parts of a self-crossing outline count as inside it - a polygon's, joined last back to first, and a polyline's, left open.

```swift
Polygon([Point(20, 0), Point(40, 40), Point(0, 15), Point(40, 15), Point(0, 40)])
    .fillRule(.evenOdd)
    .fill(.gold)
```

Worn by: [Polygon](../Polygon.md) · [Polyline](../Polyline.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Mixins/PointsShapeContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `points` | property | `[Point]` | stateUI |
| `fillRule` | property | `FillRule` | stateUI |
