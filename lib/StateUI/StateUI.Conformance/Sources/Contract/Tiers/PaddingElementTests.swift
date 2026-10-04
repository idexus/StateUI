// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `PaddingElementContract` on a host: what an element holds stands its padding in from its edges - a layout's
/// children, a control's words - and the padding the tree changes it to, on every element wearing the tier.
@_spi(Host) public enum PaddingElementTests: ConformanceFamily {
    public static let name = "PaddingElement"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(PaddingElementContract.self).flatMap { element in
            (holdsChildren(element) ? [keepsItsChildIn(element)] : [])
                + [Aspects.holds(PaddingElementContract.padding, on: element, Insets(4), then: Insets(left: 8, top: 2, right: 8, bottom: 2),
                                 with: Words.on(element))]
        }
    }

    /// Whether `element` is a layout, whose padding its children's frames show.
    static func holdsChildren(_ element: String) -> Bool {
        ["Grid", "HStack", "VStack", "ZStack", "ScrollView"].contains(element)
    }

    /// A layout's child stands its padding in from the layout's corner, and the padding the tree changes it to.
    static func keepsItsChildIn(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).keepsItsChildItsPaddingIn", proves: [
            Covered(PaddingElementContract.padding, on: element),
        ], needs: [Covered(ButtonContract.clicked)]) { s in
            let wide = State(wrappedValue: false)
            let frames = Received<[Double]>()
            s.start {
                VStack {
                    Padded.layout(element, padding: wide.wrappedValue ? Insets(left: 20, top: 12, right: 0, bottom: 0) : Insets(left: 10, top: 6, right: 0, bottom: 0)) {
                        ColorBox(.red).width(20).height(20).horizontalAlignment(.start).verticalAlignment(.start)
                            .onEvent(ViewContract.frameChanged) { frames.values.append($0) }
                    }
                    Button("Wider").onClicked { wide.wrappedValue = true }.id("change")
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }

            s.settle { frames.values.last.map(FrameReport.place)?.prefix(2) == [10, 6] }
            s.expect(frames.values.last.map(FrameReport.place).map { Array($0.prefix(2)) }, [10, 6])
            try s.perform(.activate, on: s.element("change"))
            s.settle { frames.values.last.map(FrameReport.place)?.prefix(2) == [20, 12] }
            s.expect(frames.values.last.map(FrameReport.place).map { Array($0.prefix(2)) }, [20, 12])
        }
    }
}

/// A layout of each kind holding a view within its padding.
enum Padded {
    /// A layout of `element`'s kind holding `content`, `padding` in.
    static func layout(_ element: String, padding: Insets, _ content: () -> any View) -> ModifiedContent {
        let held = ModifiedContent(node: content().node)
        let dressing = Dressing([Write(PaddingElementContract.padding, padding)], id: "layout")
        let layout: any View = switch element {
        case "Grid": dressing.dress(Grid { held })
        case "HStack": dressing.dress(HStack { held })
        case "ZStack": dressing.dress(ZStack { held })
        case "ScrollView": dressing.dress(ScrollView { held }.height(100))
        default: dressing.dress(VStack { held })
        }
        return ModifiedContent(node: layout.node)
    }
}
