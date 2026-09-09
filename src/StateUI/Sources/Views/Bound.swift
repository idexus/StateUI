// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// EVERY PROPERTY CAN BE HANDED A BINDING. The value modifiers take a value;
// these take the state as `$x`, and the host carries it - so a property whose
// value moves is never a reason to build the view again. What the host does
// with it follows from the value:
//
//   a JOURNEY   a number, a colour, a thickness: the host walks the property
//               there under the element's law, as it walks a driven
//               `MotionChannel`, and `.motion(.none)` on the element lands it
//               at once. The state goes on answering its plain type - a read
//               is where the value is going.
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
    /// `color`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: ActivityIndicator.Color.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func color(_ state: Binding<Color>) -> Modified {
        journey(.color, by: state)
    }

    /// `isRunning`, handed on as `$x`: the host sets it as it is, and writing the state renders
    /// nobody. MAUI: ActivityIndicator.IsRunning.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func isRunning(_ state: Binding<Bool>) -> Modified {
        plain(.isRunning, by: state)
    }
}

// MARK: - Border

extension Border {
    /// `strokeDashOffset`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: Border.StrokeDashOffset.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func strokeDashOffset(_ state: Binding<Double>) -> Modified {
        journey(.strokeDashOffset, by: state)
    }

    /// `strokeLineCap`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: Border.StrokeLineCap.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func strokeLineCap(_ state: Binding<PenLineCap>) -> Modified {
        plain(.strokeLineCap, by: state)
    }

    /// `strokeLineJoin`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: Border.StrokeLineJoin.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func strokeLineJoin(_ state: Binding<PenLineJoin>) -> Modified {
        plain(.strokeLineJoin, by: state)
    }

    /// `strokeMiterLimit`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: Border.StrokeMiterLimit.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func strokeMiterLimit(_ state: Binding<Double>) -> Modified {
        journey(.strokeMiterLimit, by: state)
    }

    /// `strokeThickness`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: Border.StrokeThickness.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func strokeThickness(_ state: Binding<Double>) -> Modified {
        journey(.strokeThickness, by: state)
    }
}

// MARK: - BorderElement

extension BorderElement where Self: VisualElement {
    /// `borderColor`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: IBorderElement.BorderColor.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func borderColor(_ state: Binding<Color>) -> Modified {
        journey(.borderColor, by: state)
    }

    /// `borderWidth`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: IBorderElement.BorderWidth.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func borderWidth(_ state: Binding<Double>) -> Modified {
        journey(.borderWidth, by: state)
    }

    /// `cornerRadius`, handed on as `$x`: the host sets it as it is, and writing the state renders
    /// nobody. MAUI: IBorderElement.CornerRadius.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func cornerRadius(_ state: Binding<Int>) -> Modified {
        plain(.cornerRadius, by: state)
    }
}

// MARK: - BoxView

extension BoxView {
    /// `cornerRadius`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: BoxView.CornerRadius.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func cornerRadius(_ state: Binding<Double>) -> Modified {
        plain(.cornerRadius, by: state)
    }
}

// MARK: - Button

extension Button {
    /// `lineBreakMode`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: Button.LineBreakMode.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func lineBreakMode(_ state: Binding<LineBreakMode>) -> Modified {
        plain(.lineBreakMode, by: state)
    }
}

// MARK: - DatePicker

extension DatePicker {
    /// `isOpen`, handed on as `$x`: the host sets it as it is, and writing the state renders
    /// nobody. MAUI: DatePicker.IsOpen.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func isOpen(_ state: Binding<Bool>) -> Modified {
        plain(.isOpen, by: state)
    }
}

// MARK: - DecorableTextElement

extension DecorableTextElement where Self: VisualElement {
    /// `textDecorations`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: TextDecorations.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func textDecorations(_ state: Binding<TextDecorations>) -> Modified {
        plain(.textDecorations, by: state)
    }
}

// MARK: - Editor

extension Editor {
    /// `autoSize`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: Editor.AutoSize.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func autoSize(_ state: Binding<EditorAutoSizeOption>) -> Modified {
        plain(.autoSize, by: state)
    }
}

// MARK: - Entry

extension Entry {
    /// `clearButtonVisibility`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: Entry.ClearButtonVisibility.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func clearButtonVisibility(_ state: Binding<ClearButtonVisibility>) -> Modified {
        plain(.clearButtonVisibility, by: state)
    }

    /// `isPassword`, handed on as `$x`: the host sets it as it is, and writing the state renders
    /// nobody. MAUI: Entry.IsPassword.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func isPassword(_ state: Binding<Bool>) -> Modified {
        plain(.isPassword, by: state)
    }

    /// `returnType`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: Entry.ReturnType.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func returnType(_ state: Binding<ReturnType>) -> Modified {
        plain(.returnType, by: state)
    }
}

// MARK: - FlexLayout

extension FlexLayout {
    /// `alignContent`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: FlexLayout.AlignContent.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func alignContent(_ state: Binding<FlexAlignContent>) -> Modified {
        plain(.alignContent, by: state)
    }

    /// `alignItems`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: FlexLayout.AlignItems.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func alignItems(_ state: Binding<FlexAlignItems>) -> Modified {
        plain(.alignItems, by: state)
    }

    /// `direction`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: FlexLayout.Direction.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func direction(_ state: Binding<FlexDirection>) -> Modified {
        plain(.direction, by: state)
    }

    /// `justifyContent`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: FlexLayout.JustifyContent.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func justifyContent(_ state: Binding<FlexJustify>) -> Modified {
        plain(.justifyContent, by: state)
    }

    /// `position`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: FlexLayout.Position.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func position(_ state: Binding<FlexPosition>) -> Modified {
        plain(.position, by: state)
    }

    /// `wrap`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: FlexLayout.Wrap.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func wrap(_ state: Binding<FlexWrap>) -> Modified {
        plain(.wrap, by: state)
    }
}

// MARK: - FontElement

extension FontElement where Self: VisualElement {
    /// `fontAttributes`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: FontAttributes.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func fontAttributes(_ state: Binding<FontAttributes>) -> Modified {
        plain(.fontAttributes, by: state)
    }

    /// `fontAutoScalingEnabled`, handed on as `$x`: the host sets it as it is, and writing the state renders
    /// nobody. MAUI: FontAutoScalingEnabled.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func fontAutoScalingEnabled(_ state: Binding<Bool>) -> Modified {
        plain(.fontAutoScalingEnabled, by: state)
    }

    /// `fontSize`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: FontSize.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func fontSize(_ state: Binding<Double>) -> Modified {
        journey(.fontSize, by: state)
    }
}

// MARK: - Grid

extension Grid {
    /// `columnSpacing`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: Grid.ColumnSpacing.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func columnSpacing(_ state: Binding<Double>) -> Modified {
        plain(.columnSpacing, by: state)
    }

    /// `rowSpacing`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: Grid.RowSpacing.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func rowSpacing(_ state: Binding<Double>) -> Modified {
        plain(.rowSpacing, by: state)
    }
}

// MARK: - Image

extension Image {
    /// `isAnimationPlaying`, handed on as `$x`: the host sets it as it is, and writing the state renders
    /// nobody. MAUI: Image.IsAnimationPlaying.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func isAnimationPlaying(_ state: Binding<Bool>) -> Modified {
        plain(.isAnimationPlaying, by: state)
    }
}

// MARK: - ImageElement

extension ImageElement where Self: VisualElement {
    /// `aspect`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: IImageElement.Aspect.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func aspect(_ state: Binding<Aspect>) -> Modified {
        plain(.aspect, by: state)
    }

    /// `isOpaque`, handed on as `$x`: the host sets it as it is, and writing the state renders
    /// nobody. MAUI: IImageElement.IsOpaque.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func isOpaque(_ state: Binding<Bool>) -> Modified {
        plain(.isOpaque, by: state)
    }
}

// MARK: - IndicatorView

extension IndicatorView {
    /// `count`, handed on as `$x`: the host sets it as it is, and writing the state renders
    /// nobody. MAUI: IndicatorView.Count.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func count(_ state: Binding<Int>) -> Modified {
        plain(.count, by: state)
    }

    /// `hideSingle`, handed on as `$x`: the host sets it as it is, and writing the state renders
    /// nobody. MAUI: IndicatorView.HideSingle.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func hideSingle(_ state: Binding<Bool>) -> Modified {
        plain(.hideSingle, by: state)
    }

    /// `indicatorColor`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: IndicatorView.IndicatorColor.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func indicatorColor(_ state: Binding<Color>) -> Modified {
        journey(.indicatorColor, by: state)
    }

    /// `indicatorSize`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: IndicatorView.IndicatorSize.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func indicatorSize(_ state: Binding<Double>) -> Modified {
        plain(.indicatorSize, by: state)
    }

    /// `indicatorsShape`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: IndicatorView.IndicatorsShape.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func indicatorsShape(_ state: Binding<IndicatorShape>) -> Modified {
        plain(.indicatorsShape, by: state)
    }

    /// `maximumVisible`, handed on as `$x`: the host sets it as it is, and writing the state renders
    /// nobody. MAUI: IndicatorView.MaximumVisible.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func maximumVisible(_ state: Binding<Int>) -> Modified {
        plain(.maximumVisible, by: state)
    }

    /// `selectedIndicatorColor`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: IndicatorView.SelectedIndicatorColor.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func selectedIndicatorColor(_ state: Binding<Color>) -> Modified {
        journey(.selectedIndicatorColor, by: state)
    }
}

// MARK: - InputView

extension InputView {
    /// `cursorPosition`, handed on as `$x`: the host sets it as it is, and writing the state renders
    /// nobody. MAUI: InputView.CursorPosition.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func cursorPosition(_ state: Binding<Int>) -> Modified {
        plain(.cursorPosition, by: state)
    }

    /// `isReadOnly`, handed on as `$x`: the host sets it as it is, and writing the state renders
    /// nobody. MAUI: InputView.IsReadOnly.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func isReadOnly(_ state: Binding<Bool>) -> Modified {
        plain(.isReadOnly, by: state)
    }

    /// `isSpellCheckEnabled`, handed on as `$x`: the host sets it as it is, and writing the state renders
    /// nobody. MAUI: InputView.IsSpellCheckEnabled.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func isSpellCheckEnabled(_ state: Binding<Bool>) -> Modified {
        plain(.isSpellCheckEnabled, by: state)
    }

    /// `isTextPredictionEnabled`, handed on as `$x`: the host sets it as it is, and writing the state renders
    /// nobody. MAUI: InputView.IsTextPredictionEnabled.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func isTextPredictionEnabled(_ state: Binding<Bool>) -> Modified {
        plain(.isTextPredictionEnabled, by: state)
    }

    /// `keyboard`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: InputView.Keyboard.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func keyboard(_ state: Binding<Keyboard>) -> Modified {
        plain(.keyboard, by: state)
    }

    /// `maxLength`, handed on as `$x`: the host sets it as it is, and writing the state renders
    /// nobody. MAUI: InputView.MaxLength.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func maxLength(_ state: Binding<Int>) -> Modified {
        plain(.maxLength, by: state)
    }

    /// `placeholder`, handed on as `$x`: the host writes the words, and writing the state renders
    /// nobody. MAUI: InputView.Placeholder.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func placeholder(_ state: Binding<String>) -> Modified {
        words(.placeholder, by: state)
    }

    /// `placeholderColor`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: InputView.PlaceholderColor.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func placeholderColor(_ state: Binding<Color>) -> Modified {
        journey(.placeholderColor, by: state)
    }

    /// `selectionLength`, handed on as `$x`: the host sets it as it is, and writing the state renders
    /// nobody. MAUI: InputView.SelectionLength.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func selectionLength(_ state: Binding<Int>) -> Modified {
        plain(.selectionLength, by: state)
    }
}

// MARK: - Label

extension Label {
    /// `maxLines`, handed on as `$x`: the host sets it as it is, and writing the state renders
    /// nobody. MAUI: Label.MaxLines.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func maxLines(_ state: Binding<Int>) -> Modified {
        plain(.maxLines, by: state)
    }

    /// `textType`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: Label.TextType.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func textType(_ state: Binding<TextType>) -> Modified {
        plain(.textType, by: state)
    }
}

// MARK: - Layout

extension Layout {
    /// `cascadeInputTransparent`, handed on as `$x`: the host sets it as it is, and writing the state renders
    /// nobody. MAUI: Layout.CascadeInputTransparent.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func cascadeInputTransparent(_ state: Binding<Bool>) -> Modified {
        plain(.cascadeInputTransparent, by: state)
    }

    /// `isClippedToBounds`, handed on as `$x`: the host sets it as it is, and writing the state renders
    /// nobody. MAUI: Layout.IsClippedToBounds.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func isClippedToBounds(_ state: Binding<Bool>) -> Modified {
        plain(.isClippedToBounds, by: state)
    }

    /// `safeAreaEdges`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: Layout.SafeAreaEdges.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func safeAreaEdges(_ state: Binding<SafeAreaRegions>) -> Modified {
        plain(.safeAreaEdges, by: state)
    }
}

// MARK: - Line

extension Line {
    /// `x1`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: Line.X.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func x1(_ state: Binding<Double>) -> Modified {
        journey(.x1, by: state)
    }

    /// `x2`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: Line.X.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func x2(_ state: Binding<Double>) -> Modified {
        journey(.x2, by: state)
    }

    /// `y1`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: Line.Y.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func y1(_ state: Binding<Double>) -> Modified {
        journey(.y1, by: state)
    }

    /// `y2`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: Line.Y.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func y2(_ state: Binding<Double>) -> Modified {
        journey(.y2, by: state)
    }
}

// MARK: - LineHeightElement

extension LineHeightElement where Self: VisualElement {
    /// `lineHeight`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: LineHeight.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func lineHeight(_ state: Binding<Double>) -> Modified {
        plain(.lineHeight, by: state)
    }
}

// MARK: - PaddingElement

extension PaddingElement where Self: VisualElement {
    /// `padding`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: Padding.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func padding(_ state: Binding<Thickness>) -> Modified {
        journey(.padding, by: state)
    }
}

// MARK: - Picker

extension Picker {
    /// `titleColor`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: Picker.TitleColor.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func titleColor(_ state: Binding<Color>) -> Modified {
        journey(.titleColor, by: state)
    }
}

// MARK: - Polygon

extension Polygon {
    /// `fillRule`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: Polygon.FillRule.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func fillRule(_ state: Binding<FillRule>) -> Modified {
        plain(.fillRule, by: state)
    }
}

// MARK: - ProgressBar

extension ProgressBar {
    /// `progress`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: ProgressBar.Progress.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func progress(_ state: Binding<Double>) -> Modified {
        journey(.progress, by: state)
    }

    /// `progressColor`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: ProgressBar.ProgressColor.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func progressColor(_ state: Binding<Color>) -> Modified {
        journey(.progressColor, by: state)
    }
}

// MARK: - RadioButton

extension RadioButton {
    /// `textTransform`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: RadioButton.TextTransform.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func textTransform(_ state: Binding<TextTransform>) -> Modified {
        plain(.textTransform, by: state)
    }
}

// MARK: - Rectangle

extension Rectangle {
    /// `radiusX`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: Rectangle.RadiusX.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func radiusX(_ state: Binding<Double>) -> Modified {
        plain(.radiusX, by: state)
    }

    /// `radiusY`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: Rectangle.RadiusY.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func radiusY(_ state: Binding<Double>) -> Modified {
        plain(.radiusY, by: state)
    }
}

// MARK: - RefreshView

extension RefreshView {
    /// `isRefreshEnabled`, handed on as `$x`: the host sets it as it is, and writing the state renders
    /// nobody. MAUI: RefreshView.IsRefreshEnabled.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func isRefreshEnabled(_ state: Binding<Bool>) -> Modified {
        plain(.isRefreshEnabled, by: state)
    }

    /// `refreshColor`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: RefreshView.RefreshColor.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func refreshColor(_ state: Binding<Color>) -> Modified {
        journey(.refreshColor, by: state)
    }
}

// MARK: - ScrollView

extension ScrollView {
    /// `horizontalScrollBarVisibility`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: ScrollView.HorizontalScrollBarVisibility.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func horizontalScrollBarVisibility(_ state: Binding<ScrollBarVisibility>) -> Modified {
        plain(.horizontalScrollBarVisibility, by: state)
    }

    /// `orientation`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: ScrollView.Orientation.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func orientation(_ state: Binding<ScrollOrientation>) -> Modified {
        plain(.orientation, by: state)
    }

    /// `verticalScrollBarVisibility`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: ScrollView.VerticalScrollBarVisibility.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func verticalScrollBarVisibility(_ state: Binding<ScrollBarVisibility>) -> Modified {
        plain(.verticalScrollBarVisibility, by: state)
    }
}

// MARK: - SearchBar

extension SearchBar {
    /// `cancelButtonColor`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: SearchBar.CancelButtonColor.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func cancelButtonColor(_ state: Binding<Color>) -> Modified {
        journey(.cancelButtonColor, by: state)
    }

    /// `searchIconColor`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: SearchBar.SearchIconColor.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func searchIconColor(_ state: Binding<Color>) -> Modified {
        journey(.searchIconColor, by: state)
    }
}

// MARK: - Shape

extension Shape {
    /// `aspect`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: Shape.Aspect.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func aspect(_ state: Binding<Stretch>) -> Modified {
        plain(.aspect, by: state)
    }
}

// MARK: - Slider

extension Slider {
    /// `maximum`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: Slider.Maximum.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func maximum(_ state: Binding<Double>) -> Modified {
        plain(.maximum, by: state)
    }

    /// `maximumTrackColor`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: Slider.MaximumTrackColor.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func maximumTrackColor(_ state: Binding<Color>) -> Modified {
        journey(.maximumTrackColor, by: state)
    }

    /// `minimum`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: Slider.Minimum.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func minimum(_ state: Binding<Double>) -> Modified {
        plain(.minimum, by: state)
    }

    /// `minimumTrackColor`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: Slider.MinimumTrackColor.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func minimumTrackColor(_ state: Binding<Color>) -> Modified {
        journey(.minimumTrackColor, by: state)
    }

    /// `thumbColor`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: Slider.ThumbColor.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func thumbColor(_ state: Binding<Color>) -> Modified {
        journey(.thumbColor, by: state)
    }
}

// MARK: - StackBase

extension StackBase {
    /// `spacing`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: StackBase.Spacing.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func spacing(_ state: Binding<Double>) -> Modified {
        journey(.spacing, by: state)
    }
}

// MARK: - Stepper

extension Stepper {
    /// `increment`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: Stepper.Increment.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func increment(_ state: Binding<Double>) -> Modified {
        plain(.increment, by: state)
    }
}

// MARK: - SwipeView

extension SwipeView {
    /// `threshold`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: SwipeView.Threshold.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func threshold(_ state: Binding<Double>) -> Modified {
        plain(.threshold, by: state)
    }
}

// MARK: - Switch

extension Switch {
    /// `offColor`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: Switch.OffColor.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func offColor(_ state: Binding<Color>) -> Modified {
        journey(.offColor, by: state)
    }

    /// `onColor`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: Switch.OnColor.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func onColor(_ state: Binding<Color>) -> Modified {
        journey(.onColor, by: state)
    }
}

// MARK: - TextAlignmentElement

extension TextAlignmentElement where Self: VisualElement {
    /// `horizontalTextAlignment`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: HorizontalTextAlignment.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func horizontalTextAlignment(_ state: Binding<TextAlignment>) -> Modified {
        plain(.horizontalTextAlignment, by: state)
    }

    /// `verticalTextAlignment`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: VerticalTextAlignment.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func verticalTextAlignment(_ state: Binding<TextAlignment>) -> Modified {
        plain(.verticalTextAlignment, by: state)
    }
}

// MARK: - TextStyleElement

extension TextStyleElement where Self: VisualElement {
    /// `characterSpacing`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: CharacterSpacing.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func characterSpacing(_ state: Binding<Double>) -> Modified {
        journey(.characterSpacing, by: state)
    }

    /// `textColor`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: TextColor.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func textColor(_ state: Binding<Color>) -> Modified {
        journey(.textColor, by: state)
    }
}

// MARK: - View

extension View {
    /// `absoluteLayoutFlags`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: AbsoluteLayout.LayoutFlags.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func absoluteLayoutFlags(_ state: Binding<AbsoluteLayoutFlags>) -> Modified {
        plain(.absoluteLayoutFlags, by: state)
    }

    /// `flexLayoutAlignSelf`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: FlexLayout.AlignSelf.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func flexLayoutAlignSelf(_ state: Binding<FlexAlignSelf>) -> Modified {
        plain(.flexLayoutAlignSelf, by: state)
    }

    /// `flexLayoutGrow`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: FlexLayout.Grow.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func flexLayoutGrow(_ state: Binding<Double>) -> Modified {
        plain(.flexLayoutGrow, by: state)
    }

    /// `flexLayoutOrder`, handed on as `$x`: the host sets it as it is, and writing the state renders
    /// nobody. MAUI: FlexLayout.Order.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func flexLayoutOrder(_ state: Binding<Int>) -> Modified {
        plain(.flexLayoutOrder, by: state)
    }

    /// `flexLayoutShrink`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: FlexLayout.Shrink.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func flexLayoutShrink(_ state: Binding<Double>) -> Modified {
        plain(.flexLayoutShrink, by: state)
    }

    /// `gridColumn`, handed on as `$x`: the host sets it as it is, and writing the state renders
    /// nobody. MAUI: Grid.Column.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func gridColumn(_ state: Binding<Int>) -> Modified {
        plain(.gridColumn, by: state)
    }

    /// `gridColumnSpan`, handed on as `$x`: the host sets it as it is, and writing the state renders
    /// nobody. MAUI: Grid.ColumnSpan.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func gridColumnSpan(_ state: Binding<Int>) -> Modified {
        plain(.gridColumnSpan, by: state)
    }

    /// `gridRow`, handed on as `$x`: the host sets it as it is, and writing the state renders
    /// nobody. MAUI: Grid.Row.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func gridRow(_ state: Binding<Int>) -> Modified {
        plain(.gridRow, by: state)
    }

    /// `gridRowSpan`, handed on as `$x`: the host sets it as it is, and writing the state renders
    /// nobody. MAUI: Grid.RowSpan.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func gridRowSpan(_ state: Binding<Int>) -> Modified {
        plain(.gridRowSpan, by: state)
    }

    /// `horizontalOptions`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: View.HorizontalOptions.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func horizontalOptions(_ state: Binding<LayoutOptions>) -> Modified {
        plain(.horizontalOptions, by: state)
    }

    /// `margin`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: View.Margin.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func margin(_ state: Binding<Thickness>) -> Modified {
        journey(.margin, by: state)
    }

    /// `verticalOptions`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: View.VerticalOptions.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func verticalOptions(_ state: Binding<LayoutOptions>) -> Modified {
        plain(.verticalOptions, by: state)
    }
}

// MARK: - VisualElement

extension VisualElement {
    /// `anchorX`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: VisualElement.AnchorX.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func anchorX(_ state: Binding<Double>) -> Modified {
        journey(.anchorX, by: state)
    }

    /// `anchorY`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: VisualElement.AnchorY.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func anchorY(_ state: Binding<Double>) -> Modified {
        journey(.anchorY, by: state)
    }

    /// `automationId`, handed on as `$x`: the host writes the words, and writing the state renders
    /// nobody. MAUI: Element.AutomationId.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func automationId(_ state: Binding<String>) -> Modified {
        words(.automationId, by: state)
    }

    /// `backgroundColor`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: VisualElement.BackgroundColor.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func backgroundColor(_ state: Binding<Color>) -> Modified {
        journey(.backgroundColor, by: state)
    }

    /// `flowDirection`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: VisualElement.FlowDirection.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func flowDirection(_ state: Binding<FlowDirection>) -> Modified {
        plain(.flowDirection, by: state)
    }

    /// `heightRequest`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: VisualElement.HeightRequest.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func heightRequest(_ state: Binding<Double>) -> Modified {
        journey(.heightRequest, by: state)
    }

    /// `inputTransparent`, handed on as `$x`: the host sets it as it is, and writing the state renders
    /// nobody. MAUI: VisualElement.InputTransparent.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func inputTransparent(_ state: Binding<Bool>) -> Modified {
        plain(.inputTransparent, by: state)
    }

    /// `isEnabled`, handed on as `$x`: the host sets it as it is, and writing the state renders
    /// nobody. MAUI: VisualElement.IsEnabled.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func isEnabled(_ state: Binding<Bool>) -> Modified {
        plain(.isEnabled, by: state)
    }

    /// `isVisible`, handed on as `$x`: the host sets it as it is, and writing the state renders
    /// nobody. MAUI: VisualElement.IsVisible.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func isVisible(_ state: Binding<Bool>) -> Modified {
        plain(.isVisible, by: state)
    }

    /// `maximumHeightRequest`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: VisualElement.MaximumHeightRequest.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func maximumHeightRequest(_ state: Binding<Double>) -> Modified {
        journey(.maximumHeightRequest, by: state)
    }

    /// `maximumWidthRequest`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: VisualElement.MaximumWidthRequest.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func maximumWidthRequest(_ state: Binding<Double>) -> Modified {
        journey(.maximumWidthRequest, by: state)
    }

    /// `minimumHeightRequest`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: VisualElement.MinimumHeightRequest.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func minimumHeightRequest(_ state: Binding<Double>) -> Modified {
        journey(.minimumHeightRequest, by: state)
    }

    /// `minimumWidthRequest`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: VisualElement.MinimumWidthRequest.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func minimumWidthRequest(_ state: Binding<Double>) -> Modified {
        journey(.minimumWidthRequest, by: state)
    }

    /// `opacity`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: VisualElement.Opacity.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func opacity(_ state: Binding<Double>) -> Modified {
        journey(.opacity, by: state)
    }

    /// `rotation`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: VisualElement.Rotation.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func rotation(_ state: Binding<Double>) -> Modified {
        journey(.rotation, by: state)
    }

    /// `rotationX`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: VisualElement.RotationX.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func rotationX(_ state: Binding<Double>) -> Modified {
        journey(.rotationX, by: state)
    }

    /// `rotationY`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: VisualElement.RotationY.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func rotationY(_ state: Binding<Double>) -> Modified {
        journey(.rotationY, by: state)
    }

    /// `scale`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: VisualElement.Scale.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func scale(_ state: Binding<Double>) -> Modified {
        journey(.scale, by: state)
    }

    /// `scaleX`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: VisualElement.ScaleX.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func scaleX(_ state: Binding<Double>) -> Modified {
        journey(.scaleX, by: state)
    }

    /// `scaleY`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: VisualElement.ScaleY.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func scaleY(_ state: Binding<Double>) -> Modified {
        journey(.scaleY, by: state)
    }

    /// `semanticDescription`, handed on as `$x`: the host writes the words, and writing the state renders
    /// nobody. MAUI: SemanticProperties.Description.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func semanticDescription(_ state: Binding<String>) -> Modified {
        words(.semanticDescription, by: state)
    }

    /// `semanticHeadingLevel`, handed on as `$x`: the host sets the member it names, and writing the state renders
    /// nobody. MAUI: SemanticProperties.HeadingLevel.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func semanticHeadingLevel(_ state: Binding<SemanticHeadingLevel>) -> Modified {
        plain(.semanticHeadingLevel, by: state)
    }

    /// `semanticHint`, handed on as `$x`: the host writes the words, and writing the state renders
    /// nobody. MAUI: SemanticProperties.Hint.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func semanticHint(_ state: Binding<String>) -> Modified {
        words(.semanticHint, by: state)
    }

    /// `translationX`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: VisualElement.TranslationX.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func translationX(_ state: Binding<Double>) -> Modified {
        journey(.translationX, by: state)
    }

    /// `translationY`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: VisualElement.TranslationY.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func translationY(_ state: Binding<Double>) -> Modified {
        journey(.translationY, by: state)
    }

    /// `widthRequest`, handed on as `$x`: the host walks it there under the element's law, and writing the state renders
    /// nobody. MAUI: VisualElement.WidthRequest.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func widthRequest(_ state: Binding<Double>) -> Modified {
        journey(.widthRequest, by: state)
    }

    /// `zIndex`, handed on as `$x`: the host sets it as it is, and writing the state renders
    /// nobody. MAUI: VisualElement.ZIndex.
    ///
    /// - Parameter state: the state the property is read from.
    /// - Returns: the element, with the property carried from that state.
    public func zIndex(_ state: Binding<Int>) -> Modified {
        plain(.zIndex, by: state)
    }
}
