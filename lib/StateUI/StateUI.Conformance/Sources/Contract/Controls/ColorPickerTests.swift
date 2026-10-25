// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `ColorPickerContract` on a host: the user's color heard once and landing on the state, the program's shown and
/// heard by nobody; the state chosen into painting what wears it beside; the opacity the user chose kept only where
/// the picker chooses it.
@_spi(Host) public enum ColorPickerTests: ConformanceFamily {
    public static let name = "ColorPicker"

    public static var cases: [ConformanceCase] {
        [
            Aspects.standsAlone("ColorPicker"),
            ConformanceCase("theUsersColorIsHeardAndTheProgramsIsNot", proves: [
                Covered(ColorPickerContract.color), Covered(ColorPickerContract.colorChanged),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let tint = State(wrappedValue: Color(hex: 0x4682B4))
                let heard = Received<Color>()
                s.start {
                    VStack {
                        ColorPicker(tint.projectedValue).onColorChanged { heard.values.append($0) }.id("picker")
                        Button("Gold").onClicked { tint.wrappedValue = Color(hex: 0xFFD700) }.id("change")
                    }
                }
                let picker = try s.element("picker")
                s.expect(try s.held(ColorPickerContract.color, on: picker), Color(hex: 0x4682B4))

                try s.perform(.pickColor(Color(hex: 0xB22222)), on: picker)
                s.settle { !heard.values.isEmpty }
                s.expect(heard.values, [Color(hex: 0xB22222)], "heard once")
                s.expect(tint.wrappedValue, Color(hex: 0xB22222), "and on the state")

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.held(ColorPickerContract.color, on: picker) == Color(hex: 0xFFD700) }
                s.expect(try s.held(ColorPickerContract.color, on: picker), Color(hex: 0xFFD700))
                s.expect(heard.values.count, 1, "the program's color heard by nobody")
            },
            ConformanceCase("aChosenColorPaintsWhatWearsTheSameState", proves: [
                Covered(ColorPickerContract.color),
            ], needs: [Covered(FilledShapeContract.fill, on: "Rectangle")]) { s in
                let tint = State(wrappedValue: Color.red)
                s.start {
                    VStack {
                        ColorPicker(tint.projectedValue).id("picker")
                        Rectangle().fill(tint.projectedValue).width(100).height(60).id("shape")
                    }
                    .horizontalAlignment(.start)
                }
                let shape = try s.element("shape")
                try s.settle { try s.shows(.red, on: shape, at: Point(50, 30)) }

                try s.perform(.pickColor(.blue), on: s.element("picker"))
                try s.settle { try s.shows(.blue, on: shape, at: Point(50, 30)) }
                s.expect(try s.color(of: shape, at: Point(50, 30)), shows: .blue, "the shape wears the color chosen")
                s.expect(tint.wrappedValue, .blue, "and the state holds it")
            },
            ConformanceCase("theOpacityChosenIsKeptOnlyWhereThePickerChoosesIt", proves: [
                Covered(ColorPickerContract.choosesOpacity),
            ], needs: [Covered(ColorPickerContract.colorChanged)]) { s in
                let heard = Received<Color>()
                s.start {
                    VStack {
                        ColorPicker(Color(hex: 0x4682B4)).choosesOpacity(true)
                            .onColorChanged { heard.values.append($0) }.id("seeThrough")
                        ColorPicker(Color(hex: 0x4682B4))
                            .onColorChanged { heard.values.append($0) }.id("opaque")
                    }
                }

                try s.perform(.pickColor(Color(hex: 0xB22222, opacity: 0.4)), on: s.element("seeThrough"))
                s.settle { heard.values.count == 1 }
                try s.perform(.pickColor(Color(hex: 0xB22222, opacity: 0.4)), on: s.element("opaque"))
                s.settle { heard.values.count == 2 }
                s.expect(heard.values, [Color(hex: 0xB22222, opacity: 0.4), Color(hex: 0xB22222)],
                         "the opacity kept where the picker chooses it, an opaque color where it does not")
            },
            Aspects.holds(ColorPickerContract.color, on: "ColorPicker", Color(hex: 0x4682B4), then: Color(hex: 0xB22222)),
            Aspects.holds(ColorPickerContract.choosesOpacity, on: "ColorPicker", true, then: false),
        ]
    }
}
