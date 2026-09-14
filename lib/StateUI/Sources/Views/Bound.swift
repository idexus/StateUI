// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// EVERY PROPERTY CAN BE HANDED A BINDING. The value modifiers take a value;
// these take the state as `$x`, and the host carries it - so a property whose
// value moves is never a reason to build the view again. What the host does
// with it follows from the value:
//
//   a JOURNEY   a number, a colour, a thickness: the host walks the property
//               there under the element's law - `$x.journey` is the trip -
//               and `.motion(.none)` on the element lands it at once. The
//               state goes on answering its plain type - a read is where the
//               value is going.
//   a PLAIN     a Bool, an Int, and the numbers that never travel (a range's
//               ends, a spacing, a snap grid): the host sets the property as
//               the value stands, on its own frames, and nothing walks.
//   WORDS       a String: the host writes the words, as it writes a driven
//               text.
//
// One line each, over the three helpers in Elements.swift, and generated from
// the value forms: `testEveryValueModifierHasABindingTwin` holds the two
// lists together. On the ELEMENT-side tiers, never the `…Properties` ones a
// `StyleBag` wears, for the reason Driven.swift gives.

// MARK: - ActivityIndicator

extension ActivityIndicator {

    /// `isRunning`, handed on as `$x`: the host sets it as it is, and handing
    /// it on reads nothing - a write renders only a body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func isRunning(_ state: Binding<Bool>) -> Modified {
        plain(.isRunning, by: state)
    }
}

// MARK: - Border

extension Border {
    /// `strokeDashOffset`, handed on as `$x`: the host walks it there under the
    /// element's law, and handing it on reads nothing - a write renders only a
    /// body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func strokeDashOffset(_ state: Binding<Double>) -> Modified {
        journey(.strokeDashOffset, by: state)
    }

    /// `strokeLineCap`, handed on as `$x`: the host sets the member it names,
    /// and handing it on reads nothing - a write renders only a body that reads
    /// the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func strokeLineCap(_ state: Binding<LineCap>) -> Modified {
        plain(.strokeLineCap, by: state)
    }

    /// `strokeLineJoin`, handed on as `$x`: the host sets the member it names,
    /// and handing it on reads nothing - a write renders only a body that reads
    /// the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func strokeLineJoin(_ state: Binding<LineJoin>) -> Modified {
        plain(.strokeLineJoin, by: state)
    }

    /// `strokeMiterLimit`, handed on as `$x`: the host walks it there under the
    /// element's law, and handing it on reads nothing - a write renders only a
    /// body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func strokeMiterLimit(_ state: Binding<Double>) -> Modified {
        journey(.strokeMiterLimit, by: state)
    }

    /// `strokeWidth`, handed on as `$x`: the host walks it there under the
    /// element's law, and handing it on reads nothing - a write renders only a
    /// body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func strokeWidth(_ state: Binding<Double>) -> Modified {
        journey(.strokeWidth, by: state)
    }
}

// MARK: - BorderElement

extension BorderElement where Self: VisualElement {
    /// `borderColor`, handed on as `$x`: the host walks it there under the
    /// element's law, and handing it on reads nothing - a write renders only a
    /// body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func borderColor(_ state: Binding<Color>) -> Modified {
        journey(.borderColor, by: state)
    }

    /// `borderWidth`, handed on as `$x`: the host walks it there under the
    /// element's law, and handing it on reads nothing - a write renders only a
    /// body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func borderWidth(_ state: Binding<Double>) -> Modified {
        journey(.borderWidth, by: state)
    }

    /// `cornerRadius`, handed on as `$x`: the host sets it as it is, and
    /// handing it on reads nothing - a write renders only a body that reads the
    /// state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func cornerRadius(_ state: Binding<Int>) -> Modified {
        plain(.cornerRadius, by: state)
    }
}

// MARK: - ColorBox

extension ColorBox {
    /// `color`, handed on as `$x`: the host walks it there under the element's
    /// law, and handing it on reads nothing - a write renders only a body that
    /// reads the state.
    ///
    /// Not `.background`, for the reason `color(_:)` gives: the
    /// background is a second square behind the one a box draws.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func color(_ state: Binding<Color>) -> Modified {
        journey(.color, by: state)
    }

    /// `cornerRadius`, handed on as `$x`: the host sets it as it is, and
    /// handing it on reads nothing - a write renders only a body that reads the
    /// state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func cornerRadius(_ state: Binding<Double>) -> Modified {
        plain(.cornerRadius, by: state)
    }
}

// MARK: - Button

extension Button {
    /// `iconPosition`, handed on as `$x`: the host sets the member it names,
    /// and handing it on reads nothing - a write renders only a body that reads
    /// the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func iconPosition(_ state: Binding<IconPosition>) -> Modified {
        plain(.iconPosition, by: state)
    }

    /// `iconSpacing`, handed on as `$x`: the host walks it there under the
    /// element's law, and handing it on reads nothing - a write renders only a
    /// body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func iconSpacing(_ state: Binding<Double>) -> Modified {
        journey(.iconSpacing, by: state)
    }

    /// `lineBreak`, handed on as `$x`: the host sets the member it names,
    /// and handing it on reads nothing - a write renders only a body that reads
    /// the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func lineBreak(_ state: Binding<LineBreak>) -> Modified {
        plain(.lineBreak, by: state)
    }
}

// MARK: - DatePicker

extension DatePicker {
    /// `isOpen`, handed on as `$x`: the host sets it as it is, and handing it
    /// on reads nothing - a write renders only a body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func isOpen(_ state: Binding<Bool>) -> Modified {
        plain(.isOpen, by: state)
    }
}

// MARK: - DecorableTextElement

extension DecorableTextElement where Self: VisualElement {
    /// `textDecorations`, handed on as `$x`: the host sets the member it names,
    /// and handing it on reads nothing - a write renders only a body that reads
    /// the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func textDecorations(_ state: Binding<TextDecorations>) -> Modified {
        plain(.textDecorations, by: state)
    }
}

// MARK: - TextEditor

extension TextEditor {
    /// `growsWithText`, handed on as `$x`: the host sets it as it is, and
    /// handing it on reads nothing - a write renders only a body that reads the
    /// state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func growsWithText(_ state: Binding<Bool>) -> Modified {
        plain(.growsWithText, by: state)
    }
}

// MARK: - TextField

extension TextField {
    /// `showsClearButton`, handed on as `$x`: the host sets it as it is, and
    /// handing it on reads nothing - a write renders only a body that reads the
    /// state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func showsClearButton(_ state: Binding<Bool>) -> Modified {
        plain(.showsClearButton, by: state)
    }

    /// `isPassword`, handed on as `$x`: the host sets it as it is, and handing
    /// it on reads nothing - a write renders only a body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func isPassword(_ state: Binding<Bool>) -> Modified {
        plain(.isPassword, by: state)
    }

    /// `returnKey`, handed on as `$x`: the host sets the member it names, and
    /// handing it on reads nothing - a write renders only a body that reads the
    /// state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func returnKey(_ state: Binding<ReturnKey>) -> Modified {
        plain(.returnKey, by: state)
    }
}

// MARK: - FontElement

extension FontElement where Self: VisualElement {
    /// `fontAttributes`, handed on as `$x`: the host sets the member it names,
    /// and handing it on reads nothing - a write renders only a body that reads
    /// the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func fontAttributes(_ state: Binding<FontAttributes>) -> Modified {
        plain(.fontAttributes, by: state)
    }

    /// `fontAutoScalingEnabled`, handed on as `$x`: the host sets it as it is,
    /// and handing it on reads nothing - a write renders only a body that reads
    /// the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func fontAutoScalingEnabled(_ state: Binding<Bool>) -> Modified {
        plain(.fontAutoScalingEnabled, by: state)
    }

    /// `fontSize`, handed on as `$x`: the host walks it there under the
    /// element's law, and handing it on reads nothing - a write renders only a
    /// body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func fontSize(_ state: Binding<Double>) -> Modified {
        journey(.fontSize, by: state)
    }
}

// MARK: - Grid

extension Grid {
    /// `columnSpacing`, handed on as `$x`: the host sets it as it is, and
    /// handing it on reads nothing - a write renders only a body that reads the
    /// state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func columnSpacing(_ state: Binding<Double>) -> Modified {
        plain(.columnSpacing, by: state)
    }

    /// `rowSpacing`, handed on as `$x`: the host sets it as it is, and handing
    /// it on reads nothing - a write renders only a body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func rowSpacing(_ state: Binding<Double>) -> Modified {
        plain(.rowSpacing, by: state)
    }
}

// MARK: - Image

extension Image {
    /// `isAnimating`, handed on as `$x`: the host sets it as it is, and
    /// handing it on reads nothing - a write renders only a body that reads the
    /// state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func isAnimating(_ state: Binding<Bool>) -> Modified {
        plain(.isAnimating, by: state)
    }
}

// MARK: - ImageElement

extension ImageElement where Self: VisualElement {
    /// `aspect`, handed on as `$x`: the host sets the member it names, and
    /// handing it on reads nothing - a write renders only a body that reads the
    /// state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func aspect(_ state: Binding<Aspect>) -> Modified {
        plain(.aspect, by: state)
    }
}

// MARK: - PositionIndicator

extension PositionIndicator {
    /// `count`, handed on as `$x`: the host sets it as it is, and handing it on
    /// reads nothing - a write renders only a body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func count(_ state: Binding<Int>) -> Modified {
        plain(.count, by: state)
    }

    /// `hideSingle`, handed on as `$x`: the host sets it as it is, and handing
    /// it on reads nothing - a write renders only a body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func hideSingle(_ state: Binding<Bool>) -> Modified {
        plain(.hideSingle, by: state)
    }

    /// `indicatorColor`, handed on as `$x`: the host walks it there under the
    /// element's law, and handing it on reads nothing - a write renders only a
    /// body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func indicatorColor(_ state: Binding<Color>) -> Modified {
        journey(.indicatorColor, by: state)
    }

    /// `indicatorSize`, handed on as `$x`: the host sets it as it is, and
    /// handing it on reads nothing - a write renders only a body that reads the
    /// state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func indicatorSize(_ state: Binding<Double>) -> Modified {
        plain(.indicatorSize, by: state)
    }

    /// `indicatorsShape`, handed on as `$x`: the host sets the member it names,
    /// and handing it on reads nothing - a write renders only a body that reads
    /// the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func indicatorsShape(_ state: Binding<IndicatorShape>) -> Modified {
        plain(.indicatorsShape, by: state)
    }

    /// `maximumVisible`, handed on as `$x`: the host sets it as it is, and
    /// handing it on reads nothing - a write renders only a body that reads the
    /// state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func maximumVisible(_ state: Binding<Int>) -> Modified {
        plain(.maximumVisible, by: state)
    }

    /// `selectedIndicatorColor`, handed on as `$x`: the host walks it there
    /// under the element's law, and handing it on reads nothing - a write
    /// renders only a body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func selectedIndicatorColor(_ state: Binding<Color>) -> Modified {
        journey(.selectedIndicatorColor, by: state)
    }
}

// MARK: - InputView

extension InputView {
    /// `cursorPosition`, handed on as `$x`: the host sets it as it is, and
    /// handing it on reads nothing - a write renders only a body that reads the
    /// state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func cursorPosition(_ state: Binding<Int>) -> Modified {
        plain(.cursorPosition, by: state)
    }

    /// `isReadOnly`, handed on as `$x`: the host sets it as it is, and handing
    /// it on reads nothing - a write renders only a body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func isReadOnly(_ state: Binding<Bool>) -> Modified {
        plain(.isReadOnly, by: state)
    }

    /// `isSpellCheckEnabled`, handed on as `$x`: the host sets it as it is, and
    /// handing it on reads nothing - a write renders only a body that reads the
    /// state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func isSpellCheckEnabled(_ state: Binding<Bool>) -> Modified {
        plain(.isSpellCheckEnabled, by: state)
    }

    /// `isTextPredictionEnabled`, handed on as `$x`: the host sets it as it is,
    /// and handing it on reads nothing - a write renders only a body that reads
    /// the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func isTextPredictionEnabled(_ state: Binding<Bool>) -> Modified {
        plain(.isTextPredictionEnabled, by: state)
    }

    /// `inputPurpose`, handed on as `$x`: the host sets the member it names, and
    /// handing it on reads nothing - a write renders only a body that reads the
    /// state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func inputPurpose(_ state: Binding<InputPurpose>) -> Modified {
        plain(.inputPurpose, by: state)
    }

    /// `maximumLength`, handed on as `$x`: the host sets it as it is, and handing
    /// it on reads nothing - a write renders only a body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func maximumLength(_ state: Binding<Int>) -> Modified {
        plain(.maximumLength, by: state)
    }

    /// `placeholder`, handed on as `$x`: the host writes the words, and handing
    /// it on reads nothing - a write renders only a body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func placeholder(_ state: Binding<String>) -> Modified {
        words(.placeholder, by: state)
    }

    /// `placeholderColor`, handed on as `$x`: the host walks it there under the
    /// element's law, and handing it on reads nothing - a write renders only a
    /// body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func placeholderColor(_ state: Binding<Color>) -> Modified {
        journey(.placeholderColor, by: state)
    }

    /// `selectionLength`, handed on as `$x`: the host sets it as it is, and
    /// handing it on reads nothing - a write renders only a body that reads the
    /// state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func selectionLength(_ state: Binding<Int>) -> Modified {
        plain(.selectionLength, by: state)
    }
}

// MARK: - Label

extension Label {
    /// `maximumLines`, handed on as `$x`: the host sets it as it is, and handing it
    /// on reads nothing - a write renders only a body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func maximumLines(_ state: Binding<Int>) -> Modified {
        plain(.maximumLines, by: state)
    }
}

// MARK: - Layout

extension Layout {
    /// `letsInputThrough`, handed on as `$x`: the host sets it as it is,
    /// and handing it on reads nothing - a write renders only a body that reads
    /// the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func letsInputThrough(_ state: Binding<Bool>) -> Modified {
        plain(.letsInputThrough, by: state)
    }

    /// `clipsContent`, handed on as `$x`: the host sets it as it is, and
    /// handing it on reads nothing - a write renders only a body that reads the
    /// state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func clipsContent(_ state: Binding<Bool>) -> Modified {
        plain(.clipsContent, by: state)
    }

    /// `avoidsSafeArea`, handed on as `$x`: the host sets the member it names,
    /// and handing it on reads nothing - a write renders only a body that reads
    /// the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func avoidsSafeArea(_ state: Binding<SafeArea>) -> Modified {
        plain(.avoidsSafeArea, by: state)
    }
}

// MARK: - Line

extension Line {
    /// `x1`, handed on as `$x`: the host walks it there under the element's
    /// law, and handing it on reads nothing - a write renders only a body that
    /// reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func x1(_ state: Binding<Double>) -> Modified {
        journey(.x1, by: state)
    }

    /// `x2`, handed on as `$x`: the host walks it there under the element's
    /// law, and handing it on reads nothing - a write renders only a body that
    /// reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func x2(_ state: Binding<Double>) -> Modified {
        journey(.x2, by: state)
    }

    /// `y1`, handed on as `$x`: the host walks it there under the element's
    /// law, and handing it on reads nothing - a write renders only a body that
    /// reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func y1(_ state: Binding<Double>) -> Modified {
        journey(.y1, by: state)
    }

    /// `y2`, handed on as `$x`: the host walks it there under the element's
    /// law, and handing it on reads nothing - a write renders only a body that
    /// reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func y2(_ state: Binding<Double>) -> Modified {
        journey(.y2, by: state)
    }
}

// MARK: - LineHeightElement

extension LineHeightElement where Self: VisualElement {
    /// `lineHeight`, handed on as `$x`: the host sets it as it is, and handing
    /// it on reads nothing - a write renders only a body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func lineHeight(_ state: Binding<Double>) -> Modified {
        plain(.lineHeight, by: state)
    }
}

// MARK: - PaddingElement

extension PaddingElement where Self: VisualElement {
    /// `padding`, handed on as `$x`: the host walks it there under the
    /// element's law, and handing it on reads nothing - a write renders only a
    /// body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func padding(_ state: Binding<Insets>) -> Modified {
        journey(.padding, by: state)
    }
}

// MARK: - Polygon

extension Polygon {
    /// `fillRule`, handed on as `$x`: the host sets the member it names, and
    /// handing it on reads nothing - a write renders only a body that reads the
    /// state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func fillRule(_ state: Binding<FillRule>) -> Modified {
        plain(.fillRule, by: state)
    }
}

// MARK: - ProgressBar

extension ProgressBar {
    /// `progress`, handed on as `$x`: the host walks it there under the
    /// element's law, and handing it on reads nothing - a write renders only a
    /// body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func progress(_ state: Binding<Double>) -> Modified {
        journey(.progress, by: state)
    }
}

// MARK: - RadioButton

extension RadioButton {
    /// `textCase`, handed on as `$x`: the host sets the member it names,
    /// and handing it on reads nothing - a write renders only a body that reads
    /// the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func textCase(_ state: Binding<TextCase>) -> Modified {
        plain(.textCase, by: state)
    }
}

// MARK: - Rectangle

extension Rectangle {
    /// `cornerRadius`, handed on as `$x`: the host sets it as it is, and
    /// handing it on reads nothing - a write renders only a body that reads the
    /// state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func cornerRadius(_ state: Binding<Double>) -> Modified {
        plain(.cornerRadius, by: state)
    }
}

// MARK: - RefreshView

extension RefreshView {
    /// `isRefreshEnabled`, handed on as `$x`: the host sets it as it is, and
    /// handing it on reads nothing - a write renders only a body that reads the
    /// state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func isRefreshEnabled(_ state: Binding<Bool>) -> Modified {
        plain(.isRefreshEnabled, by: state)
    }
}

// MARK: - ScrollView

extension ScrollView {
    /// `horizontalScrollBarVisibility`, handed on as `$x`: the host sets the
    /// member it names, and handing it on reads nothing - a write renders only
    /// a body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func horizontalScrollBarVisibility(_ state: Binding<ScrollBarVisibility>) -> Modified {
        plain(.horizontalScrollBarVisibility, by: state)
    }

    /// `orientation`, handed on as `$x`: the host sets the member it names, and
    /// handing it on reads nothing - a write renders only a body that reads the
    /// state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func orientation(_ state: Binding<ScrollOrientation>) -> Modified {
        plain(.orientation, by: state)
    }

    /// `verticalScrollBarVisibility`, handed on as `$x`: the host sets the
    /// member it names, and handing it on reads nothing - a write renders only
    /// a body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func verticalScrollBarVisibility(_ state: Binding<ScrollBarVisibility>) -> Modified {
        plain(.verticalScrollBarVisibility, by: state)
    }
}

// MARK: - Shape

extension Shape {
    /// `aspect`, handed on as `$x`: the host sets the member it names, and
    /// handing it on reads nothing - a write renders only a body that reads the
    /// state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func aspect(_ state: Binding<Aspect>) -> Modified {
        plain(.aspect, by: state)
    }

    /// `strokeDashOffset`, handed on as `$x`: the host walks it there under the
    /// element's law, and handing it on reads nothing - a write renders only a
    /// body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func strokeDashOffset(_ state: Binding<Double>) -> Modified {
        journey(.strokeDashOffset, by: state)
    }

    /// `strokeMiterLimit`, handed on as `$x`: the host walks it there under the
    /// element's law, and handing it on reads nothing - a write renders only a
    /// body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func strokeMiterLimit(_ state: Binding<Double>) -> Modified {
        journey(.strokeMiterLimit, by: state)
    }

    /// `strokeWidth`, handed on as `$x`: the host walks it there under the
    /// element's law, and handing it on reads nothing - a write renders only a
    /// body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func strokeWidth(_ state: Binding<Double>) -> Modified {
        journey(.strokeWidth, by: state)
    }
}

// MARK: - Slider

extension Slider {
    /// `maximum`, handed on as `$x`: the host sets it as it is, and handing it
    /// on reads nothing - a write renders only a body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func maximum(_ state: Binding<Double>) -> Modified {
        plain(.maximum, by: state)
    }

    /// `minimum`, handed on as `$x`: the host sets it as it is, and handing it
    /// on reads nothing - a write renders only a body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func minimum(_ state: Binding<Double>) -> Modified {
        plain(.minimum, by: state)
    }
}

// MARK: - StackBase

extension StackBase {
    /// `spacing`, handed on as `$x`: the host walks it there under the
    /// element's law, and handing it on reads nothing - a write renders only a
    /// body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func spacing(_ state: Binding<Double>) -> Modified {
        journey(.spacing, by: state)
    }
}

// MARK: - Stepper

extension Stepper {
    /// `step`, handed on as `$x`: the host sets it as it is, and handing
    /// it on reads nothing - a write renders only a body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func step(_ state: Binding<Double>) -> Modified {
        plain(.step, by: state)
    }
}

// MARK: - SwipeView

extension SwipeView {
    /// `threshold`, handed on as `$x`: the host sets it as it is, and handing
    /// it on reads nothing - a write renders only a body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func threshold(_ state: Binding<Double>) -> Modified {
        plain(.threshold, by: state)
    }
}

// MARK: - TextAlignmentElement

extension TextAlignmentElement where Self: VisualElement {
    /// `horizontalTextAlignment`, handed on as `$x`: the host sets the member
    /// it names, and handing it on reads nothing - a write renders only a body
    /// that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func horizontalTextAlignment(_ state: Binding<TextAlignment>) -> Modified {
        plain(.horizontalTextAlignment, by: state)
    }

    /// `verticalTextAlignment`, handed on as `$x`: the host sets the member it
    /// names, and handing it on reads nothing - a write renders only a body
    /// that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func verticalTextAlignment(_ state: Binding<TextAlignment>) -> Modified {
        plain(.verticalTextAlignment, by: state)
    }
}

// MARK: - TextStyleElement

extension TextStyleElement where Self: VisualElement {
    /// `characterSpacing`, handed on as `$x`: the host walks it there under the
    /// element's law, and handing it on reads nothing - a write renders only a
    /// body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func characterSpacing(_ state: Binding<Double>) -> Modified {
        journey(.characterSpacing, by: state)
    }

    /// `textColor`, handed on as `$x`: the host walks it there under the
    /// element's law, and handing it on reads nothing - a write renders only a
    /// body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func textColor(_ state: Binding<Color>) -> Modified {
        journey(.textColor, by: state)
    }
}

// MARK: - TintElement

extension TintElement where Self: VisualElement {
    /// `tint`, handed on as `$x`: the host walks it there under the element's
    /// law, and handing it on reads nothing - a write renders only a body that
    /// reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func tint(_ state: Binding<Color>) -> Modified {
        journey(.tint, by: state)
    }
}

// MARK: - View

extension View {
    /// `absoluteLayoutProportions`, handed on as `$x`: the host sets the member it
    /// names, and handing it on reads nothing - a write renders only a body
    /// that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func absoluteLayoutProportions(_ state: Binding<AbsoluteLayoutProportions>) -> Modified {
        plain(.absoluteLayoutProportions, by: state)
    }

    /// `gridColumn`, handed on as `$x`: the host sets it as it is, and handing
    /// it on reads nothing - a write renders only a body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func gridColumn(_ state: Binding<Int>) -> Modified {
        plain(.gridColumn, by: state)
    }

    /// `gridColumnSpan`, handed on as `$x`: the host sets it as it is, and
    /// handing it on reads nothing - a write renders only a body that reads the
    /// state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func gridColumnSpan(_ state: Binding<Int>) -> Modified {
        plain(.gridColumnSpan, by: state)
    }

    /// `gridRow`, handed on as `$x`: the host sets it as it is, and handing it
    /// on reads nothing - a write renders only a body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func gridRow(_ state: Binding<Int>) -> Modified {
        plain(.gridRow, by: state)
    }

    /// `gridRowSpan`, handed on as `$x`: the host sets it as it is, and handing
    /// it on reads nothing - a write renders only a body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func gridRowSpan(_ state: Binding<Int>) -> Modified {
        plain(.gridRowSpan, by: state)
    }

    /// `horizontalAlignment`, handed on as `$x`: the host sets the member it
    /// names, and handing it on reads nothing - a write renders only a body
    /// that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func horizontalAlignment(_ state: Binding<Alignment>) -> Modified {
        plain(.horizontalAlignment, by: state)
    }

    /// `margin`, handed on as `$x`: the host walks it there under the element's
    /// law, and handing it on reads nothing - a write renders only a body that
    /// reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func margin(_ state: Binding<Insets>) -> Modified {
        journey(.margin, by: state)
    }

    /// `verticalAlignment`, handed on as `$x`: the host sets the member it names,
    /// and handing it on reads nothing - a write renders only a body that reads
    /// the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func verticalAlignment(_ state: Binding<Alignment>) -> Modified {
        plain(.verticalAlignment, by: state)
    }
}

// MARK: - VisualElement

extension VisualElement {
    /// `pivotX`, handed on as `$x`: the host walks it there under the
    /// element's law, and handing it on reads nothing - a write renders only a
    /// body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func pivotX(_ state: Binding<Double>) -> Modified {
        journey(.pivotX, by: state)
    }

    /// `pivotY`, handed on as `$x`: the host walks it there under the
    /// element's law, and handing it on reads nothing - a write renders only a
    /// body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func pivotY(_ state: Binding<Double>) -> Modified {
        journey(.pivotY, by: state)
    }

    /// `accessibilityIdentifier`, handed on as `$x`: the host writes the words, and
    /// handing it on reads nothing - a write renders only a body that reads the
    /// state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func accessibilityIdentifier(_ state: Binding<String>) -> Modified {
        words(.accessibilityIdentifier, by: state)
    }

    /// `automationExcludedWithChildren`, handed on as `$x`: the host sets it as
    /// it is, and handing it on reads nothing - a write renders only a body
    /// that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func automationExcludedWithChildren(_ state: Binding<Bool>) -> Modified {
        plain(.automationExcludedWithChildren, by: state)
    }

    /// `isAccessibilityHidden`, handed on as `$x`: the host sets it as
    /// it is, and handing it on reads nothing - a write renders only a body
    /// that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func isAccessibilityHidden(_ state: Binding<Bool>) -> Modified {
        plain(.isAccessibilityHidden, by: state)
    }

    /// `background`, handed on as `$x`: the host walks it there under the
    /// element's law, and handing it on reads nothing - a write renders only a
    /// body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func background(_ state: Binding<Color>) -> Modified {
        journey(.background, by: state)
    }

    /// `layoutDirection`, handed on as `$x`: the host sets the member it names,
    /// and handing it on reads nothing - a write renders only a body that reads
    /// the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func layoutDirection(_ state: Binding<LayoutDirection>) -> Modified {
        plain(.layoutDirection, by: state)
    }

    /// `height`, handed on as `$x`: the host walks it there under the
    /// element's law, and handing it on reads nothing - a write renders only a
    /// body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func height(_ state: Binding<Double>) -> Modified {
        journey(.height, by: state)
    }

    /// `ignoresInput`, handed on as `$x`: the host sets it as it is, and
    /// handing it on reads nothing - a write renders only a body that reads the
    /// state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func ignoresInput(_ state: Binding<Bool>) -> Modified {
        plain(.ignoresInput, by: state)
    }

    /// `isEnabled`, handed on as `$x`: the host sets it as it is, and handing
    /// it on reads nothing - a write renders only a body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func isEnabled(_ state: Binding<Bool>) -> Modified {
        plain(.isEnabled, by: state)
    }

    /// `isVisible`, handed on as `$x`: the host sets it as it is, and handing
    /// it on reads nothing - a write renders only a body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func isVisible(_ state: Binding<Bool>) -> Modified {
        plain(.isVisible, by: state)
    }

    /// `maximumHeight`, handed on as `$x`: the host walks it there under
    /// the element's law, and handing it on reads nothing - a write renders
    /// only a body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func maximumHeight(_ state: Binding<Double>) -> Modified {
        journey(.maximumHeight, by: state)
    }

    /// `maximumWidth`, handed on as `$x`: the host walks it there under
    /// the element's law, and handing it on reads nothing - a write renders
    /// only a body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func maximumWidth(_ state: Binding<Double>) -> Modified {
        journey(.maximumWidth, by: state)
    }

    /// `minimumHeight`, handed on as `$x`: the host walks it there under
    /// the element's law, and handing it on reads nothing - a write renders
    /// only a body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func minimumHeight(_ state: Binding<Double>) -> Modified {
        journey(.minimumHeight, by: state)
    }

    /// `minimumWidth`, handed on as `$x`: the host walks it there under
    /// the element's law, and handing it on reads nothing - a write renders
    /// only a body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func minimumWidth(_ state: Binding<Double>) -> Modified {
        journey(.minimumWidth, by: state)
    }

    /// `opacity`, handed on as `$x`: the host walks it there under the
    /// element's law, and handing it on reads nothing - a write renders only a
    /// body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func opacity(_ state: Binding<Double>) -> Modified {
        journey(.opacity, by: state)
    }

    /// `rotation`, handed on as `$x`: the host walks it there under the
    /// element's law, and handing it on reads nothing - a write renders only a
    /// body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func rotation(_ state: Binding<Double>) -> Modified {
        journey(.rotation, by: state)
    }

    /// `rotationX`, handed on as `$x`: the host walks it there under the
    /// element's law, and handing it on reads nothing - a write renders only a
    /// body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func rotationX(_ state: Binding<Double>) -> Modified {
        journey(.rotationX, by: state)
    }

    /// `rotationY`, handed on as `$x`: the host walks it there under the
    /// element's law, and handing it on reads nothing - a write renders only a
    /// body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func rotationY(_ state: Binding<Double>) -> Modified {
        journey(.rotationY, by: state)
    }

    /// `scale`, handed on as `$x`: the host walks it there under the element's
    /// law, and handing it on reads nothing - a write renders only a body that
    /// reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func scale(_ state: Binding<Double>) -> Modified {
        journey(.scale, by: state)
    }

    /// `scaleX`, handed on as `$x`: the host walks it there under the element's
    /// law, and handing it on reads nothing - a write renders only a body that
    /// reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func scaleX(_ state: Binding<Double>) -> Modified {
        journey(.scaleX, by: state)
    }

    /// `scaleY`, handed on as `$x`: the host walks it there under the element's
    /// law, and handing it on reads nothing - a write renders only a body that
    /// reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func scaleY(_ state: Binding<Double>) -> Modified {
        journey(.scaleY, by: state)
    }

    /// `accessibilityLabel`, handed on as `$x`: the host writes the words, and
    /// handing it on reads nothing - a write renders only a body that reads the
    /// state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func accessibilityLabel(_ state: Binding<String>) -> Modified {
        words(.accessibilityLabel, by: state)
    }

    /// `accessibilityHeadingLevel`, handed on as `$x`: the host sets the member it
    /// names, and handing it on reads nothing - a write renders only a body
    /// that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func accessibilityHeadingLevel(_ state: Binding<HeadingLevel>) -> Modified {
        plain(.accessibilityHeadingLevel, by: state)
    }

    /// `accessibilityHint`, handed on as `$x`: the host writes the words, and
    /// handing it on reads nothing - a write renders only a body that reads the
    /// state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func accessibilityHint(_ state: Binding<String>) -> Modified {
        words(.accessibilityHint, by: state)
    }

    /// `translationX`, handed on as `$x`: the host walks it there under the
    /// element's law, and handing it on reads nothing - a write renders only a
    /// body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func translationX(_ state: Binding<Double>) -> Modified {
        journey(.translationX, by: state)
    }

    /// `translationY`, handed on as `$x`: the host walks it there under the
    /// element's law, and handing it on reads nothing - a write renders only a
    /// body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func translationY(_ state: Binding<Double>) -> Modified {
        journey(.translationY, by: state)
    }

    /// `width`, handed on as `$x`: the host walks it there under the
    /// element's law, and handing it on reads nothing - a write renders only a
    /// body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func width(_ state: Binding<Double>) -> Modified {
        journey(.width, by: state)
    }

    /// `zIndex`, handed on as `$x`: the host sets it as it is, and handing it
    /// on reads nothing - a write renders only a body that reads the state.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func zIndex(_ state: Binding<Int>) -> Modified {
        plain(.zIndex, by: state)
    }
}
