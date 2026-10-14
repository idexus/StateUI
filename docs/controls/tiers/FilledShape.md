<!-- Rendered by ControlDictionaryTests from the contracts and the verdicts each host's runs of its tests wrote under lib/StateUI/exports/marks: STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests writes it again. -->

# FilledShape

A shape enclosing an area its fill paints - every shape but a line.

```swift
Ellipse()
    .fill(.gold)
    .stroke(.black)
    .width(40)
    .height(40)
```

Wears: [Shape](Shape.md)

Worn by: [Capsule](../Capsule.md) · [Ellipse](../Ellipse.md) · [Path](../Path.md) · [Polygon](../Polygon.md) · [Polyline](../Polyline.md) · [Rectangle](../Rectangle.md)

Declared in `lib/StateUI/Core/Sources/Contracts/Tiers/FilledShapeContract.swift`.

How each of them realizes these members is on its own page.

| Member | Kind | Value | Layer |
| --- | --- | --- | --- |
| `fill` | property | `Brush` | stateUI |
