// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The binding twin of every value modifier: the property carried from a state,
// `$x`, which the host animates, sets or writes with no view rebuilt.
// Design: docs/design/views/bindings.md#binding-twins

// MARK: - ActivityIndicator

extension ActivityIndicator {

    /// `isRunning` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func isRunning(_ state: Binding<Bool>) -> Modified {
        plain(.isRunning, by: state)
    }
}

// MARK: - Border

extension Border {
    /// `strokeDashOffset` from a state, `$x`: the host animates the property to
    /// each new value, and no view is rebuilt for it.
    public func strokeDashOffset(_ state: Binding<Double>) -> Modified {
        journey(BorderContract.strokeDashOffset.token, by: state)
    }

    /// `strokeLineCap` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func strokeLineCap(_ state: Binding<LineCap>) -> Modified {
        plain(BorderContract.strokeLineCap.token, by: state)
    }

    /// `strokeLineJoin` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func strokeLineJoin(_ state: Binding<LineJoin>) -> Modified {
        plain(BorderContract.strokeLineJoin.token, by: state)
    }

    /// `strokeMiterLimit` from a state, `$x`: the host animates the property to
    /// each new value, and no view is rebuilt for it.
    public func strokeMiterLimit(_ state: Binding<Double>) -> Modified {
        journey(BorderContract.strokeMiterLimit.token, by: state)
    }

    /// `strokeWidth` from a state, `$x`: the host animates the property to each
    /// new value, and no view is rebuilt for it.
    public func strokeWidth(_ state: Binding<Double>) -> Modified {
        journey(BorderContract.strokeWidth.token, by: state)
    }
}

// MARK: - BorderElement

extension BorderElement where Self: VisualElement {
    /// `borderColor` from a state, `$x`: the host animates the property to each
    /// new value, and no view is rebuilt for it.
    public func borderColor(_ state: Binding<Color>) -> Modified {
        journey(BorderElementContract.borderColor, by: state)
    }

    /// `borderWidth` from a state, `$x`: the host animates the property to each
    /// new value, and no view is rebuilt for it.
    public func borderWidth(_ state: Binding<Double>) -> Modified {
        journey(BorderElementContract.borderWidth, by: state)
    }

    /// `cornerRadius` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func cornerRadius(_ state: Binding<Int>) -> Modified {
        plain(BorderElementContract.cornerRadius, by: state)
    }
}

// MARK: - ColorBox

extension ColorBox {
    /// `color` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    /// Not `.background`, which is a second square behind the one a box draws.
    public func color(_ state: Binding<Color>) -> Modified {
        journey(.color, by: state)
    }

    /// `cornerRadius` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func cornerRadius(_ state: Binding<Double>) -> Modified {
        plain(ColorBoxContract.cornerRadius.token, by: state)
    }
}

// MARK: - Button

extension Button {
    /// `iconPosition` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func iconPosition(_ state: Binding<IconPosition>) -> Modified {
        plain(.iconPosition, by: state)
    }

    /// `iconSpacing` from a state, `$x`: the host animates the property to each
    /// new value, and no view is rebuilt for it.
    public func iconSpacing(_ state: Binding<Double>) -> Modified {
        journey(.iconSpacing, by: state)
    }

    /// `lineBreak` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func lineBreak(_ state: Binding<LineBreak>) -> Modified {
        plain(ButtonContract.lineBreak.token, by: state)
    }
}

// MARK: - DatePicker

extension DatePicker {
    /// `isOpen` from a state, `$x`: the host sets each new value as it stands,
    /// and no view is rebuilt for it.
    public func isOpen(_ state: Binding<Bool>) -> Modified {
        plain(DatePickerContract.isOpen.token, by: state)
    }
}

// MARK: - DecorableTextElement

extension DecorableTextElement where Self: VisualElement {
    /// `textDecorations` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func textDecorations(_ state: Binding<TextDecorations>) -> Modified {
        plain(DecorableTextElementContract.textDecorations, by: state)
    }
}

// MARK: - TextEditor

extension TextEditor {
    /// `growsWithText` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func growsWithText(_ state: Binding<Bool>) -> Modified {
        plain(.growsWithText, by: state)
    }
}

// MARK: - TextField

extension TextField {
    /// `showsClearButton` from a state, `$x`: the host sets each new value as
    /// it stands, and no view is rebuilt for it.
    public func showsClearButton(_ state: Binding<Bool>) -> Modified {
        plain(.showsClearButton, by: state)
    }

    /// `isPassword` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func isPassword(_ state: Binding<Bool>) -> Modified {
        plain(.isPassword, by: state)
    }

    /// `returnKey` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func returnKey(_ state: Binding<ReturnKey>) -> Modified {
        plain(TextFieldContract.returnKey.token, by: state)
    }
}

// MARK: - FontElement

extension FontElement where Self: VisualElement {
    /// `fontAttributes` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func fontAttributes(_ state: Binding<FontAttributes>) -> Modified {
        plain(FontElementContract.fontAttributes, by: state)
    }

    /// `fontAutoScalingEnabled` from a state, `$x`: the host sets each new
    /// value as it stands, and no view is rebuilt for it.
    public func fontAutoScalingEnabled(_ state: Binding<Bool>) -> Modified {
        plain(FontElementContract.fontAutoScalingEnabled, by: state)
    }

    /// `fontSize` from a state, `$x`: the host animates the property to each
    /// new value, and no view is rebuilt for it.
    public func fontSize(_ state: Binding<Double>) -> Modified {
        journey(FontElementContract.fontSize, by: state)
    }
}

// MARK: - Grid

extension Grid {
    /// `columnSpacing` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func columnSpacing(_ state: Binding<Double>) -> Modified {
        plain(.columnSpacing, by: state)
    }

    /// `rowSpacing` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func rowSpacing(_ state: Binding<Double>) -> Modified {
        plain(.rowSpacing, by: state)
    }
}

// MARK: - Image

extension Image {
    /// `isAnimating` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func isAnimating(_ state: Binding<Bool>) -> Modified {
        plain(.isAnimating, by: state)
    }
}

// MARK: - ImageElement

extension ImageElement where Self: VisualElement {
    /// `aspect` from a state, `$x`: the host sets each new value as it stands,
    /// and no view is rebuilt for it.
    public func aspect(_ state: Binding<Aspect>) -> Modified {
        plain(ImageElementContract.aspect, by: state)
    }
}

// MARK: - PositionIndicator

extension PositionIndicator {
    /// `count` from a state, `$x`: the host sets each new value as it stands,
    /// and no view is rebuilt for it.
    public func count(_ state: Binding<Int>) -> Modified {
        plain(.count, by: state)
    }

    /// `hideSingle` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func hideSingle(_ state: Binding<Bool>) -> Modified {
        plain(.hideSingle, by: state)
    }

    /// `indicatorColor` from a state, `$x`: the host animates the property to
    /// each new value, and no view is rebuilt for it.
    public func indicatorColor(_ state: Binding<Color>) -> Modified {
        journey(.indicatorColor, by: state)
    }

    /// `indicatorSize` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func indicatorSize(_ state: Binding<Double>) -> Modified {
        plain(.indicatorSize, by: state)
    }

    /// `indicatorsShape` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func indicatorsShape(_ state: Binding<IndicatorShape>) -> Modified {
        plain(.indicatorsShape, by: state)
    }

    /// `maximumVisible` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func maximumVisible(_ state: Binding<Int>) -> Modified {
        plain(.maximumVisible, by: state)
    }

    /// `selectedIndicatorColor` from a state, `$x`: the host animates the
    /// property to each new value, and no view is rebuilt for it.
    public func selectedIndicatorColor(_ state: Binding<Color>) -> Modified {
        journey(.selectedIndicatorColor, by: state)
    }
}

// MARK: - InputView

extension InputView {
    /// `cursorPosition` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func cursorPosition(_ state: Binding<Int>) -> Modified {
        plain(InputViewContract.cursorPosition, by: state)
    }

    /// `isReadOnly` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func isReadOnly(_ state: Binding<Bool>) -> Modified {
        plain(InputViewContract.isReadOnly, by: state)
    }

    /// `isSpellCheckEnabled` from a state, `$x`: the host sets each new value
    /// as it stands, and no view is rebuilt for it.
    public func isSpellCheckEnabled(_ state: Binding<Bool>) -> Modified {
        plain(InputViewContract.isSpellCheckEnabled, by: state)
    }

    /// `isTextPredictionEnabled` from a state, `$x`: the host sets each new
    /// value as it stands, and no view is rebuilt for it.
    public func isTextPredictionEnabled(_ state: Binding<Bool>) -> Modified {
        plain(InputViewContract.isTextPredictionEnabled, by: state)
    }

    /// `inputPurpose` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func inputPurpose(_ state: Binding<InputPurpose>) -> Modified {
        plain(InputViewContract.inputPurpose, by: state)
    }

    /// `maximumLength` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func maximumLength(_ state: Binding<Int>) -> Modified {
        plain(InputViewContract.maximumLength, by: state)
    }

    /// `placeholder` from a state, `$x`: the host writes each new text, and no
    /// view is rebuilt for it.
    public func placeholder(_ state: Binding<String>) -> Modified {
        words(InputViewContract.placeholder, by: state)
    }

    /// `placeholderColor` from a state, `$x`: the host animates the property to
    /// each new value, and no view is rebuilt for it.
    public func placeholderColor(_ state: Binding<Color>) -> Modified {
        journey(InputViewContract.placeholderColor, by: state)
    }

    /// `selectionLength` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func selectionLength(_ state: Binding<Int>) -> Modified {
        plain(InputViewContract.selectionLength, by: state)
    }
}

// MARK: - Label

extension Label {
    /// `maximumLines` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func maximumLines(_ state: Binding<Int>) -> Modified {
        plain(.maximumLines, by: state)
    }
}

// MARK: - Layout

extension Layout {
    /// `letsInputThrough` from a state, `$x`: the host sets each new value as
    /// it stands, and no view is rebuilt for it.
    public func letsInputThrough(_ state: Binding<Bool>) -> Modified {
        plain(LayoutContract.letsInputThrough, by: state)
    }

    /// `clipsContent` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func clipsContent(_ state: Binding<Bool>) -> Modified {
        plain(LayoutContract.clipsContent, by: state)
    }

    /// `avoidsSafeArea` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func avoidsSafeArea(_ state: Binding<SafeArea>) -> Modified {
        plain(LayoutContract.avoidsSafeArea.token, by: state)
    }
}

// MARK: - Line

extension Line {
    /// `x1` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    public func x1(_ state: Binding<Double>) -> Modified {
        journey(.x1, by: state)
    }

    /// `x2` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    public func x2(_ state: Binding<Double>) -> Modified {
        journey(.x2, by: state)
    }

    /// `y1` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    public func y1(_ state: Binding<Double>) -> Modified {
        journey(.y1, by: state)
    }

    /// `y2` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    public func y2(_ state: Binding<Double>) -> Modified {
        journey(.y2, by: state)
    }
}

// MARK: - LineHeightElement

extension LineHeightElement where Self: VisualElement {
    /// `lineHeight` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func lineHeight(_ state: Binding<Double>) -> Modified {
        plain(LineHeightElementContract.lineHeight, by: state)
    }
}

// MARK: - PaddingElement

extension PaddingElement where Self: VisualElement {
    /// `padding` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    public func padding(_ state: Binding<Insets>) -> Modified {
        journey(PaddingElementContract.padding, by: state)
    }
}

// MARK: - Polygon

extension Polygon {
    /// `fillRule` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func fillRule(_ state: Binding<FillRule>) -> Modified {
        plain(PolygonContract.fillRule.token, by: state)
    }
}

// MARK: - ProgressBar

extension ProgressBar {
    /// `progress` from a state, `$x`: the host animates the property to each
    /// new value, and no view is rebuilt for it.
    public func progress(_ state: Binding<Double>) -> Modified {
        journey(.progress, by: state)
    }
}

// MARK: - RadioButton

extension RadioButton {
    /// `textCase` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func textCase(_ state: Binding<TextCase>) -> Modified {
        plain(.textCase, by: state)
    }
}

// MARK: - Rectangle

extension Rectangle {
    /// `cornerRadius` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func cornerRadius(_ state: Binding<Double>) -> Modified {
        plain(RectangleContract.cornerRadius.token, by: state)
    }
}

// MARK: - RefreshView

extension RefreshView {
    /// `isRefreshEnabled` from a state, `$x`: the host sets each new value as
    /// it stands, and no view is rebuilt for it.
    public func isRefreshEnabled(_ state: Binding<Bool>) -> Modified {
        plain(.isRefreshEnabled, by: state)
    }
}

// MARK: - ScrollView

extension ScrollView {
    /// `horizontalScrollBarVisibility` from a state, `$x`: the host sets each
    /// new value as it stands, and no view is rebuilt for it.
    public func horizontalScrollBarVisibility(_ state: Binding<ScrollBarVisibility>) -> Modified {
        plain(.horizontalScrollBarVisibility, by: state)
    }

    /// `orientation` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func orientation(_ state: Binding<ScrollOrientation>) -> Modified {
        plain(.orientation, by: state)
    }

    /// `verticalScrollBarVisibility` from a state, `$x`: the host sets each new
    /// value as it stands, and no view is rebuilt for it.
    public func verticalScrollBarVisibility(_ state: Binding<ScrollBarVisibility>) -> Modified {
        plain(.verticalScrollBarVisibility, by: state)
    }
}

// MARK: - Shape

extension Shape {
    /// `aspect` from a state, `$x`: the host sets each new value as it stands,
    /// and no view is rebuilt for it.
    public func aspect(_ state: Binding<Aspect>) -> Modified {
        plain(ShapeContract.aspect, by: state)
    }

    /// `strokeDashOffset` from a state, `$x`: the host animates the property to
    /// each new value, and no view is rebuilt for it.
    public func strokeDashOffset(_ state: Binding<Double>) -> Modified {
        journey(ShapeContract.strokeDashOffset, by: state)
    }

    /// `strokeMiterLimit` from a state, `$x`: the host animates the property to
    /// each new value, and no view is rebuilt for it.
    public func strokeMiterLimit(_ state: Binding<Double>) -> Modified {
        journey(ShapeContract.strokeMiterLimit, by: state)
    }

    /// `strokeWidth` from a state, `$x`: the host animates the property to each
    /// new value, and no view is rebuilt for it.
    public func strokeWidth(_ state: Binding<Double>) -> Modified {
        journey(ShapeContract.strokeWidth, by: state)
    }
}

// MARK: - Slider

extension Slider {
    /// `maximum` from a state, `$x`: the host sets each new value as it stands,
    /// and no view is rebuilt for it.
    public func maximum(_ state: Binding<Double>) -> Modified {
        plain(SliderContract.maximum.token, by: state)
    }

    /// `minimum` from a state, `$x`: the host sets each new value as it stands,
    /// and no view is rebuilt for it.
    public func minimum(_ state: Binding<Double>) -> Modified {
        plain(SliderContract.minimum.token, by: state)
    }
}

// MARK: - StackBase

extension StackBase {
    /// `spacing` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    public func spacing(_ state: Binding<Double>) -> Modified {
        journey(StackBaseContract.spacing, by: state)
    }
}

// MARK: - Stepper

extension Stepper {
    /// `step` from a state, `$x`: the host sets each new value as it stands,
    /// and no view is rebuilt for it.
    public func step(_ state: Binding<Double>) -> Modified {
        plain(.step, by: state)
    }
}

// MARK: - SwipeView

extension SwipeView {
    /// `threshold` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func threshold(_ state: Binding<Double>) -> Modified {
        plain(.threshold, by: state)
    }
}

// MARK: - TextAlignmentElement

extension TextAlignmentElement where Self: VisualElement {
    /// `horizontalTextAlignment` from a state, `$x`: the host sets each new
    /// value as it stands, and no view is rebuilt for it.
    public func horizontalTextAlignment(_ state: Binding<TextAlignment>) -> Modified {
        plain(TextAlignmentElementContract.horizontalTextAlignment, by: state)
    }

    /// `verticalTextAlignment` from a state, `$x`: the host sets each new value
    /// as it stands, and no view is rebuilt for it.
    public func verticalTextAlignment(_ state: Binding<TextAlignment>) -> Modified {
        plain(TextAlignmentElementContract.verticalTextAlignment, by: state)
    }
}

// MARK: - TextStyleElement

extension TextStyleElement where Self: VisualElement {
    /// `characterSpacing` from a state, `$x`: the host animates the property to
    /// each new value, and no view is rebuilt for it.
    public func characterSpacing(_ state: Binding<Double>) -> Modified {
        journey(TextStyleElementContract.characterSpacing, by: state)
    }

    /// `textColor` from a state, `$x`: the host animates the property to each
    /// new value, and no view is rebuilt for it.
    public func textColor(_ state: Binding<Color>) -> Modified {
        journey(TextStyleElementContract.textColor, by: state)
    }
}

// MARK: - TintElement

extension TintElement where Self: VisualElement {
    /// `tint` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    public func tint(_ state: Binding<Color>) -> Modified {
        journey(TintElementContract.tint, by: state)
    }
}

// MARK: - View

extension View {
    /// `absoluteLayoutProportions` from a state, `$x`: the host sets each new
    /// value as it stands, and no view is rebuilt for it.
    public func absoluteLayoutProportions(_ state: Binding<AbsoluteLayoutProportions>) -> Modified {
        plain(ViewContract.absoluteLayoutProportions, by: state)
    }

    /// `gridColumn` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func gridColumn(_ state: Binding<Int>) -> Modified {
        plain(ViewContract.gridColumn, by: state)
    }

    /// `gridColumnSpan` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func gridColumnSpan(_ state: Binding<Int>) -> Modified {
        plain(ViewContract.gridColumnSpan, by: state)
    }

    /// `gridRow` from a state, `$x`: the host sets each new value as it stands,
    /// and no view is rebuilt for it.
    public func gridRow(_ state: Binding<Int>) -> Modified {
        plain(ViewContract.gridRow, by: state)
    }

    /// `gridRowSpan` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func gridRowSpan(_ state: Binding<Int>) -> Modified {
        plain(ViewContract.gridRowSpan, by: state)
    }

    /// `horizontalAlignment` from a state, `$x`: the host sets each new value
    /// as it stands, and no view is rebuilt for it.
    public func horizontalAlignment(_ state: Binding<Alignment>) -> Modified {
        plain(ViewContract.horizontalAlignment, by: state)
    }

    /// `margin` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    public func margin(_ state: Binding<Insets>) -> Modified {
        journey(ViewContract.margin, by: state)
    }

    /// `verticalAlignment` from a state, `$x`: the host sets each new value as
    /// it stands, and no view is rebuilt for it.
    public func verticalAlignment(_ state: Binding<Alignment>) -> Modified {
        plain(ViewContract.verticalAlignment, by: state)
    }
}

// MARK: - VisualElement

extension VisualElement {
    /// `pivotX` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    public func pivotX(_ state: Binding<Double>) -> Modified {
        journey(VisualElementContract.pivotX, by: state)
    }

    /// `pivotY` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    public func pivotY(_ state: Binding<Double>) -> Modified {
        journey(VisualElementContract.pivotY, by: state)
    }

    /// `accessibilityIdentifier` from a state, `$x`: the host writes each new
    /// text, and no view is rebuilt for it.
    public func accessibilityIdentifier(_ state: Binding<String>) -> Modified {
        words(PropertyContainerContract.accessibilityIdentifier, by: state)
    }

    /// `automationExcludedWithChildren` from a state, `$x`: the host sets each
    /// new value as it stands, and no view is rebuilt for it.
    public func automationExcludedWithChildren(_ state: Binding<Bool>) -> Modified {
        plain(VisualElementContract.automationExcludedWithChildren, by: state)
    }

    /// `isAccessibilityHidden` from a state, `$x`: the host sets each new value
    /// as it stands, and no view is rebuilt for it.
    public func isAccessibilityHidden(_ state: Binding<Bool>) -> Modified {
        plain(VisualElementContract.isAccessibilityHidden, by: state)
    }

    /// `background` from a state, `$x`: the host animates the property to each
    /// new value, and no view is rebuilt for it.
    public func background(_ state: Binding<Color>) -> Modified {
        journey(VisualElementContract.background.token, by: state)
    }

    /// `layoutDirection` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func layoutDirection(_ state: Binding<LayoutDirection>) -> Modified {
        plain(VisualElementContract.layoutDirection, by: state)
    }

    /// `height` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    public func height(_ state: Binding<Double>) -> Modified {
        journey(VisualElementContract.height, by: state)
    }

    /// `ignoresInput` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func ignoresInput(_ state: Binding<Bool>) -> Modified {
        plain(VisualElementContract.ignoresInput, by: state)
    }

    /// `isEnabled` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func isEnabled(_ state: Binding<Bool>) -> Modified {
        plain(VisualElementContract.isEnabled, by: state)
    }

    /// `isVisible` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func isVisible(_ state: Binding<Bool>) -> Modified {
        plain(VisualElementContract.isVisible, by: state)
    }

    /// `maximumHeight` from a state, `$x`: the host animates the property to
    /// each new value, and no view is rebuilt for it.
    public func maximumHeight(_ state: Binding<Double>) -> Modified {
        journey(VisualElementContract.maximumHeight, by: state)
    }

    /// `maximumWidth` from a state, `$x`: the host animates the property to
    /// each new value, and no view is rebuilt for it.
    public func maximumWidth(_ state: Binding<Double>) -> Modified {
        journey(VisualElementContract.maximumWidth, by: state)
    }

    /// `minimumHeight` from a state, `$x`: the host animates the property to
    /// each new value, and no view is rebuilt for it.
    public func minimumHeight(_ state: Binding<Double>) -> Modified {
        journey(VisualElementContract.minimumHeight, by: state)
    }

    /// `minimumWidth` from a state, `$x`: the host animates the property to
    /// each new value, and no view is rebuilt for it.
    public func minimumWidth(_ state: Binding<Double>) -> Modified {
        journey(VisualElementContract.minimumWidth, by: state)
    }

    /// `opacity` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    public func opacity(_ state: Binding<Double>) -> Modified {
        journey(VisualElementContract.opacity, by: state)
    }

    /// `rotation` from a state, `$x`: the host animates the property to each
    /// new value, and no view is rebuilt for it.
    public func rotation(_ state: Binding<Double>) -> Modified {
        journey(VisualElementContract.rotation, by: state)
    }

    /// `rotationX` from a state, `$x`: the host animates the property to each
    /// new value, and no view is rebuilt for it.
    public func rotationX(_ state: Binding<Double>) -> Modified {
        journey(VisualElementContract.rotationX, by: state)
    }

    /// `rotationY` from a state, `$x`: the host animates the property to each
    /// new value, and no view is rebuilt for it.
    public func rotationY(_ state: Binding<Double>) -> Modified {
        journey(VisualElementContract.rotationY, by: state)
    }

    /// `scale` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    public func scale(_ state: Binding<Double>) -> Modified {
        journey(VisualElementContract.scale, by: state)
    }

    /// `scaleX` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    public func scaleX(_ state: Binding<Double>) -> Modified {
        journey(VisualElementContract.scaleX, by: state)
    }

    /// `scaleY` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    public func scaleY(_ state: Binding<Double>) -> Modified {
        journey(VisualElementContract.scaleY, by: state)
    }

    /// `accessibilityLabel` from a state, `$x`: the host writes each new text,
    /// and no view is rebuilt for it.
    public func accessibilityLabel(_ state: Binding<String>) -> Modified {
        words(VisualElementContract.accessibilityLabel, by: state)
    }

    /// `accessibilityHeadingLevel` from a state, `$x`: the host sets each new
    /// value as it stands, and no view is rebuilt for it.
    public func accessibilityHeadingLevel(_ state: Binding<HeadingLevel>) -> Modified {
        plain(VisualElementContract.accessibilityHeadingLevel, by: state)
    }

    /// `accessibilityHint` from a state, `$x`: the host writes each new text,
    /// and no view is rebuilt for it.
    public func accessibilityHint(_ state: Binding<String>) -> Modified {
        words(VisualElementContract.accessibilityHint, by: state)
    }

    /// `translationX` from a state, `$x`: the host animates the property to
    /// each new value, and no view is rebuilt for it.
    public func translationX(_ state: Binding<Double>) -> Modified {
        journey(VisualElementContract.translationX, by: state)
    }

    /// `translationY` from a state, `$x`: the host animates the property to
    /// each new value, and no view is rebuilt for it.
    public func translationY(_ state: Binding<Double>) -> Modified {
        journey(VisualElementContract.translationY, by: state)
    }

    /// `width` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    public func width(_ state: Binding<Double>) -> Modified {
        journey(VisualElementContract.width, by: state)
    }

    /// `zIndex` from a state, `$x`: the host sets each new value as it stands,
    /// and no view is rebuilt for it.
    public func zIndex(_ state: Binding<Int>) -> Modified {
        plain(VisualElementContract.zIndex, by: state)
    }
}
