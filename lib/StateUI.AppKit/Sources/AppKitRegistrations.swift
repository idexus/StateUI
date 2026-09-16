// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

/// The contracts this host realizes through the core's registry: how each
/// element's view is made, which of its members the view takes, and what it
/// reports. Families move here from `MountedNode`'s switch one at a time; an
/// element no registration answers is still made there.
@MainActor
enum AppKitRegistrations {
    /// The registry, built once.
    static let registry: Registry<NSView> = {
        let registry = Registry<NSView>()

        indicators(registry)
        toggles(registry)
        values(registry)
        pickers(registry)
        fields(registry)
        shapes(registry)
        drawing(registry)
        layouts(registry)
        presentation(registry)

        return registry
    }()

    /// Progress and activity: one value each, and no event.
    private static func indicators(_ registry: Registry<NSView>) {
        registry.add(ProgressBarContract.self, create: { _ in AppKitProgressView() }) { bar in
            bar.property(ProgressBarContract.progress) { view, progress in
                view.apply(progress: progress ?? 0)
            }
        }

        registry.add(ActivityIndicatorContract.self, create: { _ in AppKitActivityIndicatorView() }) { activity in
            activity.property(ActivityIndicatorContract.isRunning) { view, running in
                view.apply(running: running ?? false)
            }
        }
    }

    /// A switch, a check box and a radio button: one value the reader turns on,
    /// taken whole with the enabled state - and, for the radio button, the
    /// caption it draws in the font and case the tree describes. Which of the
    /// set's other buttons lose their check is the host's, not the view's: a
    /// set is named across the window, and only the tree knows who is in it.
    private static func toggles(_ registry: Registry<NSView>) {
        registry.add(SwitchContract.self, create: { reports in
            let toggle = AppKitSwitchView()
            toggle.onToggled = { on in
                reports.report(SwitchContract.isOn, on, as: SwitchContract.toggled)
            }
            return toggle
        }, members: { toggle in
            toggle.applies([SwitchContract.isOn, VisualElementContract.isEnabled]) { view, values in
                view.apply(
                    toggled: values[SwitchContract.isOn] ?? false,
                    enabled: values[VisualElementContract.isEnabled] ?? true)
            }
            toggle.raises(SwitchContract.toggled)
        })

        registry.add(CheckBoxContract.self, create: { reports in
            let box = AppKitCheckBoxView()
            box.onToggled = { on in
                reports.report(CheckBoxContract.isOn, on, as: CheckBoxContract.toggled)
            }
            return box
        }, members: { box in
            box.applies([
                CheckBoxContract.isOn, VisualElementContract.isEnabled, TintElementContract.tint,
            ]) { view, values in
                view.apply(
                    checked: values[CheckBoxContract.isOn] ?? false,
                    enabled: values[VisualElementContract.isEnabled] ?? true,
                    tint: values[TintElementContract.tint].flatMap { nsColor($0.propValue) })
            }
            box.raises(CheckBoxContract.toggled)
        })

        registry.add(RadioButtonContract.self, create: { reports in
            let radio = AppKitRadioButtonView()
            radio.onSelected = {
                reports.report(RadioButtonContract.isOn, true, as: RadioButtonContract.toggled)
            }
            return radio
        }, members: { radio in
            radio.applies([
                RadioButtonContract.isOn, TextElementContract.text, TextElementContract.textCase,
                FontElementContract.fontFamily, FontElementContract.fontSize,
                FontElementContract.fontAttributes, TextStyleElementContract.textColor,
                VisualElementContract.isEnabled,
            ]) { view, values in
                view.apply(
                    checked: values[RadioButtonContract.isOn] ?? false,
                    text: appKitTextCased(
                        values[TextElementContract.text] ?? "",
                        values[TextElementContract.textCase]?.rawValue),
                    font: appKitFont(
                        family: values[FontElementContract.fontFamily]?.text,
                        size: values[FontElementContract.fontSize],
                        attributes: values[FontElementContract.fontAttributes]?.rawValue,
                        fallback: NSFont.systemFont(ofSize: NSFont.systemFontSize)),
                    textColor: values[TextStyleElementContract.textColor]
                        .flatMap { nsColor($0.propValue) } ?? .controlTextColor,
                    enabled: values[VisualElementContract.isEnabled] ?? true)
            }
            radio.raises(RadioButtonContract.toggled)
        })
    }

    /// A slider and a stepper: one number the reader moves, inside the range
    /// its element describes. The value is written onto the native control only
    /// where the tree changed it, so a hand on the thumb is never argued with.
    private static func values(_ registry: Registry<NSView>) {
        registry.add(SliderContract.self, create: { reports in
            let slider = AppKitSliderView()
            slider.onValueChanged = { moved in
                reports.report(SliderContract.value, moved, as: SliderContract.valueChanged)
            }
            slider.onDragStarted = { reports.raise(SliderContract.dragStarted) }
            slider.onDragCompleted = { reports.raise(SliderContract.dragCompleted) }
            return slider
        }, members: { slider in
            slider.applies([
                SliderContract.value, SliderContract.minimum, SliderContract.maximum,
                TintElementContract.tint, VisualElementContract.isEnabled,
            ]) { view, values in
                let moved = values[SliderContract.value]

                view.apply(
                    value: moved,
                    writeValue: values.changed(SliderContract.value) && moved != nil,
                    minimum: values[SliderContract.minimum] ?? 0,
                    maximum: values[SliderContract.maximum] ?? 1,
                    tint: values[TintElementContract.tint].flatMap { nsColor($0.propValue) },
                    enabled: values[VisualElementContract.isEnabled] ?? true)
            }
            slider.raises(SliderContract.valueChanged)
            slider.raises(SliderContract.dragStarted)
            slider.raises(SliderContract.dragCompleted)
        })

        registry.add(StepperContract.self, create: { reports in
            let stepper = AppKitStepperView()
            stepper.onValueChanged = { stepped in
                reports.report(StepperContract.value, stepped, as: StepperContract.valueChanged)
            }
            return stepper
        }, members: { stepper in
            stepper.applies([
                StepperContract.value, StepperContract.minimum, StepperContract.maximum,
                StepperContract.step, VisualElementContract.isEnabled,
            ]) { view, values in
                view.apply(
                    value: values[StepperContract.value],
                    writeValue: values.changed(StepperContract.value),
                    minimum: values[StepperContract.minimum] ?? 0,
                    maximum: values[StepperContract.maximum] ?? 100,
                    step: values[StepperContract.step] ?? 1,
                    enabled: values[VisualElementContract.isEnabled] ?? true)
            }
            stepper.raises(StepperContract.valueChanged)
        })
    }

    /// A choice, a date and a time: what the reader picks, reported by member.
    /// A date and a time travel as the lanes their types carry, which is how
    /// StateUI keeps a civil date out of an absolute instant's zone.
    private static func pickers(_ registry: Registry<NSView>) {
        registry.add(PickerContract.self, create: { reports in
            let picker = AppKitPickerView()
            picker.onSelectionChanged = { index in
                reports.report(PickerContract.selectedIndex, index, as: PickerContract.selectedIndexChanged)
            }
            picker.onOpened = { reports.raise(PickerContract.opened) }
            picker.onClosed = { reports.raise(PickerContract.closed) }
            return picker
        }, members: { picker in
            picker.applies([
                PickerContract.options, PickerContract.selectedIndex, PickerContract.title,
                PickerContract.isOpen, FontElementContract.fontFamily, FontElementContract.fontSize,
                FontElementContract.fontAttributes, TextStyleElementContract.textColor,
                TintElementContract.tint, TextAlignmentElementContract.horizontalTextAlignment,
                VisualElementContract.isEnabled,
            ]) { view, values in
                view.apply(
                    items: values[PickerContract.options] ?? [],
                    selectedIndex: values[PickerContract.selectedIndex] ?? -1,
                    writeSelection: values.changed(PickerContract.selectedIndex),
                    title: values[PickerContract.title],
                    font: appKitFont(
                        family: values[FontElementContract.fontFamily]?.text,
                        size: values[FontElementContract.fontSize],
                        attributes: values[FontElementContract.fontAttributes]?.rawValue,
                        fallback: NSFont.systemFont(ofSize: NSFont.systemFontSize)),
                    textColor: values[TextStyleElementContract.textColor]
                        .flatMap { nsColor($0.propValue) } ?? .controlTextColor,
                    tint: values[TintElementContract.tint].flatMap { nsColor($0.propValue) },
                    alignment: appKitTextAlignment(
                        values[TextAlignmentElementContract.horizontalTextAlignment]?.rawValue),
                    enabled: values[VisualElementContract.isEnabled] ?? true,
                    open: values[PickerContract.isOpen] ?? false,
                    writeOpen: values.changed(PickerContract.isOpen))
            }
            picker.raises(PickerContract.selectedIndexChanged)
            picker.raises(PickerContract.opened)
            picker.raises(PickerContract.closed)
        })

        registry.add(DatePickerContract.self, create: { reports in
            let picker = AppKitDateTimePickerView(mode: .date)
            picker.onValueChanged = { lanes in
                guard let picked = CalendarDate(propValue: .numbers(lanes)) else { return }

                reports.report(DatePickerContract.date, picked, as: DatePickerContract.dateChanged)
            }
            return picker
        }, members: { picker in
            picker.applies([
                DatePickerContract.date, DatePickerContract.minimumDate, DatePickerContract.maximumDate,
                FontElementContract.fontFamily, FontElementContract.fontSize,
                FontElementContract.fontAttributes, TextStyleElementContract.textColor,
                VisualElementContract.isEnabled,
            ]) { view, values in
                view.apply(
                    value: values[DatePickerContract.date]?.propValue.numbers,
                    writeValue: values.changed(DatePickerContract.date),
                    minimum: values[DatePickerContract.minimumDate]?.propValue.numbers,
                    maximum: values[DatePickerContract.maximumDate]?.propValue.numbers,
                    font: appKitFont(
                        family: values[FontElementContract.fontFamily]?.text,
                        size: values[FontElementContract.fontSize],
                        attributes: values[FontElementContract.fontAttributes]?.rawValue,
                        fallback: NSFont.systemFont(ofSize: NSFont.systemFontSize)),
                    textColor: values[TextStyleElementContract.textColor]
                        .flatMap { nsColor($0.propValue) } ?? .controlTextColor,
                    enabled: values[VisualElementContract.isEnabled] ?? true)
            }
            picker.raises(DatePickerContract.dateChanged)
        })

        registry.add(TimePickerContract.self, create: { reports in
            let picker = AppKitDateTimePickerView(mode: .time)
            picker.onValueChanged = { lanes in
                guard let picked = ClockTime(propValue: .numbers(lanes)) else { return }

                reports.report(TimePickerContract.time, picked, as: TimePickerContract.timeChanged)
            }
            return picker
        }, members: { picker in
            picker.applies([
                TimePickerContract.time, FontElementContract.fontFamily, FontElementContract.fontSize,
                FontElementContract.fontAttributes, TextStyleElementContract.textColor,
                VisualElementContract.isEnabled,
            ]) { view, values in
                view.apply(
                    value: values[TimePickerContract.time]?.propValue.numbers,
                    writeValue: values.changed(TimePickerContract.time),
                    minimum: nil,
                    maximum: nil,
                    font: appKitFont(
                        family: values[FontElementContract.fontFamily]?.text,
                        size: values[FontElementContract.fontSize],
                        attributes: values[FontElementContract.fontAttributes]?.rawValue,
                        fallback: NSFont.systemFont(ofSize: NSFont.systemFontSize)),
                    textColor: values[TextStyleElementContract.textColor]
                        .flatMap { nsColor($0.propValue) } ?? .controlTextColor,
                    enabled: values[VisualElementContract.isEnabled] ?? true)
            }
            picker.raises(TimePickerContract.timeChanged)
        })
    }

    /// The fields a reader types in. Their words are `TextElementContract.text`
    /// and the change they report is `InputViewContract.textChanged` - two
    /// tiers, both worn. A text the host CARRIES IN is the host's to write, so
    /// the tree's words are not put over it; anything else the tree describes
    /// reaches the control only where the tree changed it, which is what keeps
    /// a reader's typing and a reader's caret their own.
    private static func fields(_ registry: Registry<NSView>) {
        registry.add(TextFieldContract.self, create: { reports in
            let entry = AppKitTextFieldView()
            entry.onTextChanged = { typed in
                reports.report(TextElementContract.text, typed, as: InputViewContract.textChanged)
            }
            entry.onSubmitted = { reports.raise(TextFieldContract.submitted) }
            return entry
        }, members: { entry in
            entry.applies(Self.fieldMembers + [TextFieldContract.isPassword]) { view, values in
                let words = Self.words(values)

                view.apply(
                    text: words,
                    writeText: values.changed(TextElementContract.text) && words != nil,
                    placeholder: values[InputViewContract.placeholder],
                    placeholderColor: values[InputViewContract.placeholderColor]
                        .flatMap { nsColor($0.propValue) },
                    foregroundColor: values[TextStyleElementContract.textColor]
                        .flatMap { nsColor($0.propValue) } ?? .controlTextColor,
                    backgroundColor: values[VisualElementContract.background]
                        .flatMap { nsColor($0.propValue) },
                    font: Self.font(values),
                    horizontalAlignment: values[TextAlignmentElementContract.horizontalTextAlignment]?.rawValue,
                    enabled: values[VisualElementContract.isEnabled] ?? true,
                    readOnly: values[InputViewContract.isReadOnly] ?? false,
                    secure: values[TextFieldContract.isPassword] ?? false,
                    maximumLength: values[InputViewContract.maximumLength],
                    spellChecking: values[InputViewContract.isSpellCheckEnabled] ?? true,
                    textPrediction: values[InputViewContract.isTextPredictionEnabled] ?? true,
                    cursorPosition: values[InputViewContract.cursorPosition],
                    selectionLength: values[InputViewContract.selectionLength],
                    writeSelection: Self.writesSelection(values))
            }
            entry.raises(InputViewContract.textChanged)
            entry.raises(TextFieldContract.submitted)
        })

        registry.add(TextEditorContract.self, create: { reports in
            let editor = AppKitTextEditorView()
            editor.onTextChanged = { typed in
                reports.report(TextElementContract.text, typed, as: InputViewContract.textChanged)
            }
            return editor
        }, members: { editor in
            editor.applies(Self.fieldMembers + [TextEditorContract.growsWithText]) { view, values in
                let words = Self.words(values)

                view.apply(
                    text: words,
                    writeText: values.changed(TextElementContract.text) && words != nil,
                    placeholder: values[InputViewContract.placeholder],
                    placeholderColor: values[InputViewContract.placeholderColor]
                        .flatMap { nsColor($0.propValue) },
                    foregroundColor: values[TextStyleElementContract.textColor]
                        .flatMap { nsColor($0.propValue) } ?? .controlTextColor,
                    backgroundColor: values[VisualElementContract.background]
                        .flatMap { nsColor($0.propValue) },
                    font: Self.font(values),
                    horizontalAlignment: values[TextAlignmentElementContract.horizontalTextAlignment]?.rawValue,
                    enabled: values[VisualElementContract.isEnabled] ?? true,
                    readOnly: values[InputViewContract.isReadOnly] ?? false,
                    maximumLength: values[InputViewContract.maximumLength],
                    spellChecking: values[InputViewContract.isSpellCheckEnabled] ?? true,
                    textPrediction: values[InputViewContract.isTextPredictionEnabled] ?? true,
                    cursorPosition: values[InputViewContract.cursorPosition],
                    selectionLength: values[InputViewContract.selectionLength],
                    writeSelection: Self.writesSelection(values),
                    growsWithText: values[TextEditorContract.growsWithText] == true)
            }
            editor.raises(InputViewContract.textChanged)
        })

        registry.add(SearchFieldContract.self, create: { reports in
            let search = AppKitSearchFieldView()
            search.onTextChanged = { typed in
                reports.report(TextElementContract.text, typed, as: InputViewContract.textChanged)
            }
            search.onSubmitted = { reports.raise(SearchFieldContract.submitted) }
            return search
        }, members: { search in
            search.applies(Self.fieldMembers) { view, values in
                let words = Self.words(values)

                view.apply(
                    text: words,
                    writeText: values.changed(TextElementContract.text) && words != nil,
                    placeholder: values[InputViewContract.placeholder],
                    placeholderColor: values[InputViewContract.placeholderColor]
                        .flatMap { nsColor($0.propValue) },
                    foregroundColor: values[TextStyleElementContract.textColor]
                        .flatMap { nsColor($0.propValue) } ?? .controlTextColor,
                    backgroundColor: values[VisualElementContract.background]
                        .flatMap { nsColor($0.propValue) },
                    font: Self.font(values),
                    horizontalAlignment: values[TextAlignmentElementContract.horizontalTextAlignment]?.rawValue,
                    enabled: values[VisualElementContract.isEnabled] ?? true,
                    readOnly: values[InputViewContract.isReadOnly] ?? false,
                    maximumLength: values[InputViewContract.maximumLength],
                    spellChecking: values[InputViewContract.isSpellCheckEnabled] ?? true,
                    textPrediction: values[InputViewContract.isTextPredictionEnabled] ?? true,
                    cursorPosition: values[InputViewContract.cursorPosition],
                    selectionLength: values[InputViewContract.selectionLength],
                    writeSelection: Self.writesSelection(values))
            }
            search.raises(InputViewContract.textChanged)
            search.raises(SearchFieldContract.submitted)
        })
    }

    /// The shapes and the box they are drawn beside. Six elements share one
    /// native view and one tier - `ShapeContract` carries the stroke, the fill
    /// and the transform, and each element adds only the geometry it is: a
    /// radius, four coordinates, a path's data, a run of points. The box is its
    /// own thing: two colours and a radius.
    private static func shapes(_ registry: Registry<NSView>) {
        registry.add(RectangleContract.self, create: { _ in AppKitShapeView(kind: .rectangle) }) { shape in
            shape.applies(Self.shapeMembers + [RectangleContract.cornerRadius]) { view, values in
                Self.draw(view, values, .rectangle(
                    AppKitCornerRadii(values[RectangleContract.cornerRadius]?.propValue)))
            }
        }

        registry.add(EllipseContract.self, create: { _ in AppKitShapeView(kind: .ellipse) }) { shape in
            shape.applies(Self.shapeMembers) { view, values in
                Self.draw(view, values, .ellipse)
            }
        }

        registry.add(LineContract.self, create: { _ in AppKitShapeView(kind: .line) }) { shape in
            shape.applies(Self.shapeMembers + [
                LineContract.x1, LineContract.y1, LineContract.x2, LineContract.y2,
            ]) { view, values in
                Self.draw(view, values, .line(
                    x1: CGFloat(values[LineContract.x1] ?? 0),
                    y1: CGFloat(values[LineContract.y1] ?? 0),
                    x2: CGFloat(values[LineContract.x2] ?? 0),
                    y2: CGFloat(values[LineContract.y2] ?? 0)))
            }
        }

        registry.add(PathContract.self, create: { _ in AppKitShapeView(kind: .path) }) { shape in
            shape.applies(Self.shapeMembers + [PathContract.data]) { view, values in
                Self.draw(view, values, .path(values[PathContract.data] ?? ""))
            }
        }

        registry.add(PolygonContract.self, create: { _ in AppKitShapeView(kind: .polygon) }) { shape in
            shape.applies(Self.shapeMembers + [PolygonContract.points, PolygonContract.fillRule]) { view, values in
                Self.draw(view, values, .points(
                    values[PolygonContract.points]?.propValue.numbers ?? [],
                    fillRule: values[PolygonContract.fillRule]?.rawValue ?? 0))
            }
        }

        registry.add(PolylineContract.self, create: { _ in AppKitShapeView(kind: .polyline) }) { shape in
            shape.applies(Self.shapeMembers + [PolylineContract.points, PolylineContract.fillRule]) { view, values in
                Self.draw(view, values, .points(
                    values[PolylineContract.points]?.propValue.numbers ?? [],
                    fillRule: values[PolylineContract.fillRule]?.rawValue ?? 0))
            }
        }

        registry.add(ColorBoxContract.self, create: { _ in AppKitColorBoxView() }) { box in
            box.applies([
                ColorBoxContract.color, ColorBoxContract.cornerRadius, VisualElementContract.background,
            ]) { view, values in
                view.apply(
                    background: values[VisualElementContract.background].flatMap { nsColor($0.propValue) },
                    fill: values[ColorBoxContract.color].flatMap { nsColor($0.propValue) },
                    cornerRadius: values[ColorBoxContract.cornerRadius]?.propValue)
            }
        }
    }

    /// The surface an application draws on, and the finger it answers.
    ///
    /// A drawing is ONE value that replaces the one before it, so the canvas
    /// takes it whole rather than instruction by instruction. The three
    /// reports carry where the finger was, in the canvas's own coordinates -
    /// the ones the instructions use.
    private static func drawing(_ registry: Registry<NSView>) {
        registry.add(CanvasContract.self, create: { reports in
            let canvas = AppKitCanvasView()
            canvas.onPressed = { point in
                reports.raise(CanvasContract.pressed, Point(x: point.x, y: point.y))
            }
            canvas.onDragged = { point in
                reports.raise(CanvasContract.dragged, Point(x: point.x, y: point.y))
            }
            canvas.onReleased = { point in
                reports.raise(CanvasContract.released, Point(x: point.x, y: point.y))
            }
            return canvas
        }, members: { canvas in
            canvas.property(CanvasContract.drawable) { view, drawing in
                view.apply(drawing)
            }
            canvas.raises(CanvasContract.pressed)
            canvas.raises(CanvasContract.dragged)
            canvas.raises(CanvasContract.released)
        })
    }

    /// What every shape wears, whatever shape it is.
    private static let shapeMembers: [any ContractMember] = [
        ShapeContract.fill, ShapeContract.stroke, ShapeContract.strokeWidth,
        ShapeContract.strokeDashPattern, ShapeContract.strokeDashOffset,
        ShapeContract.strokeLineCap, ShapeContract.strokeLineJoin, ShapeContract.strokeMiterLimit,
        ShapeContract.aspect, ShapeContract.renderTransform,
    ]

    /// The stacks and the grid: the room a layout leaves around and between
    /// its children. What ARRANGES the children is not here - a layout walks
    /// its own rows and keeps the ones it recycles, which is the host's work,
    /// and a registration describes one view.
    private static func layouts(_ registry: Registry<NSView>) {
        registry.add(VStackContract.self, create: { _ in AppKitStackView(axis: .vertical) }) { stack in
            stack.applies(Self.stackMembers) { view, values in
                view.spacing = CGFloat(values[StackBaseContract.spacing] ?? 0)
                view.padding = Self.edgeInsets(values[PaddingElementContract.padding])
            }
        }

        registry.add(HStackContract.self, create: { _ in AppKitStackView(axis: .horizontal) }) { stack in
            stack.applies(Self.stackMembers) { view, values in
                view.spacing = CGFloat(values[StackBaseContract.spacing] ?? 0)
                view.padding = Self.edgeInsets(values[PaddingElementContract.padding])
            }
        }

        // THE HOST MAKES THIS ONE. A scroll view reports through a reader
        // transaction and asks the host for display frames, and neither is an
        // event of its contract - so its making stays in `AppKitHost`, and the
        // registration takes the members alone.
        registry.add(ScrollViewContract.self, madeByHost: AppKitScrollView.self) { scroll in
            scroll.applies([
                ScrollViewContract.orientation,
                ScrollViewContract.verticalScrollBarVisibility,
                ScrollViewContract.horizontalScrollBarVisibility,
                ScrollViewContract.scrollOffset,
                PaddingElementContract.padding,
            ]) { view, values in
                // THE OFFSET IS WRITTEN ONLY WHERE THE TREE MOVED IT: a
                // reader's own scrolling comes back as the state it wrote, and
                // putting the clip view back where it already stands
                // interrupts the platform's own scroll mid-gesture.
                let offset = values.changed(ScrollViewContract.scrollOffset)
                    ? values[ScrollViewContract.scrollOffset].map { NSPoint(x: $0.x, y: $0.y) }
                    : nil

                view.apply(
                    orientation: (values[ScrollViewContract.orientation] ?? .vertical).rawValue,
                    padding: Self.edgeInsets(values[PaddingElementContract.padding]),
                    verticalBarVisibility:
                        (values[ScrollViewContract.verticalScrollBarVisibility] ?? .default).rawValue,
                    horizontalBarVisibility:
                        (values[ScrollViewContract.horizontalScrollBarVisibility] ?? .default).rawValue,
                    offset: offset)
            }
        }

        registry.add(GridContract.self, create: { _ in AppKitGridView() }) { grid in
            grid.applies([
                GridContract.rows, GridContract.columns,
                GridContract.rowSpacing, GridContract.columnSpacing,
                PaddingElementContract.padding,
            ]) { view, values in
                view.rows = Self.gridLengths(values[GridContract.rows])
                view.columns = Self.gridLengths(values[GridContract.columns])
                view.rowSpacing = CGFloat(values[GridContract.rowSpacing] ?? 0)
                view.columnSpacing = CGFloat(values[GridContract.columnSpacing] ?? 0)
                view.padding = Self.edgeInsets(values[PaddingElementContract.padding])
            }
        }
    }

    /// What both stacks take: the space between their children, and the space
    /// kept inside their own edge.
    private static let stackMembers: [any ContractMember] = [
        StackBaseContract.spacing, PaddingElementContract.padding,
    ]

    /// Insets travel as left, top, right, bottom.
    /// The presentation elements whose VIEWS THE HOST MAKES: a page and a
    /// split view are woven through its page machinery - a split view's report
    /// walks into its first child's page lifetime, which no contract describes
    /// - so a registration takes their values alone, and both the making and
    /// the arranging of their children stay the host's.
    private static func presentation(_ registry: Registry<NSView>) {
        registry.add(PageContract.self, madeByHost: AppKitSingleChildView.self) { page in
            page.property(PageContract.padding) { view, padding in
                view.padding = Self.edgeInsets(padding)
            }
        }

        registry.add(SplitViewContract.self, madeByHost: AppKitSplitView.self) { split in
            split.property(SplitViewContract.isSidebarVisible) { view, visible in
                view.apply(presented: visible ?? false)
            }
        }
    }

    private static func edgeInsets(_ value: Insets?) -> NSEdgeInsets {
        guard let numbers = value?.propValue.numbers, numbers.count >= 4 else { return NSEdgeInsets() }

        return NSEdgeInsets(
            top: numbers[1], left: numbers[0], bottom: numbers[3], right: numbers[2])
    }

    /// A row or a column is a kind and an amount, and travels as the two of
    /// them - a LIST OF VALUES, as a render transform does.
    private static func gridLengths(_ value: [GridLength]?) -> [AppKitGridLength] {
        value?.propValue.values?.compactMap(AppKitGridLength.init) ?? []
    }

    /// The six components a render transform travels as - a LIST OF VALUES, not
    /// a list of numbers - or none where it is not six numbers.
    private static func transform<Realized: ElementContract>(
        _ values: ElementValues<Realized>
    ) -> [Double]? {
        guard let components = values[ShapeContract.renderTransform]?.propValue.values,
              components.count == 6
        else { return nil }

        let numbers = components.compactMap(\.number)
        return numbers.count == components.count ? numbers : nil
    }

    /// The stroke, the fill and the transform every shape draws with, around
    /// the one geometry it is.
    private static func draw<Realized: ElementContract>(
        _ view: AppKitShapeView,
        _ values: ElementValues<Realized>,
        _ geometry: AppKitShapeGeometry
    ) {
        view.apply(
            fill: values[ShapeContract.fill]?.propValue,
            stroke: values[ShapeContract.stroke]?.propValue,
            strokeWidth: values[ShapeContract.strokeWidth] ?? 1,
            dash: values[ShapeContract.strokeDashPattern] ?? [],
            dashOffset: values[ShapeContract.strokeDashOffset] ?? 0,
            lineCap: values[ShapeContract.strokeLineCap]?.rawValue ?? 0,
            lineJoin: values[ShapeContract.strokeLineJoin]?.rawValue ?? 0,
            miterLimit: values[ShapeContract.strokeMiterLimit] ?? 10,
            aspect: values[ShapeContract.aspect]?.rawValue ?? 0,
            renderTransform: Self.transform(values),
            geometry: geometry)
    }

    /// What every field takes, whatever kind of field it is.
    private static let fieldMembers: [any ContractMember] = [
        TextElementContract.text, InputViewContract.placeholder, InputViewContract.placeholderColor,
        TextStyleElementContract.textColor, VisualElementContract.background,
        FontElementContract.fontFamily, FontElementContract.fontSize, FontElementContract.fontAttributes,
        TextAlignmentElementContract.horizontalTextAlignment, VisualElementContract.isEnabled,
        InputViewContract.isReadOnly, InputViewContract.maximumLength,
        InputViewContract.isSpellCheckEnabled, InputViewContract.isTextPredictionEnabled,
        InputViewContract.cursorPosition, InputViewContract.selectionLength,
    ]

    /// The words to put on a field: NONE where the host carries the text in,
    /// since the control is the source there and the tree describes it only to
    /// read back - and otherwise what the tree says, which is empty where the
    /// tree took the words away, so clearing a field clears the control.
    private static func words<Realized: ElementContract>(_ values: ElementValues<Realized>) -> String? {
        values.carriedIn(TextElementContract.text) ? nil : (values[TextElementContract.text] ?? "")
    }

    /// The caret moves only where the tree moved it, never because something
    /// else about the field changed.
    private static func writesSelection<Realized: ElementContract>(
        _ values: ElementValues<Realized>
    ) -> Bool {
        values.changed(InputViewContract.cursorPosition) || values.changed(InputViewContract.selectionLength)
    }

    /// The font a field draws in, composed from the members it wears.
    private static func font<Realized: ElementContract>(_ values: ElementValues<Realized>) -> NSFont {
        appKitFont(
            family: values[FontElementContract.fontFamily]?.text,
            size: values[FontElementContract.fontSize],
            attributes: values[FontElementContract.fontAttributes]?.rawValue,
            fallback: NSFont.systemFont(ofSize: NSFont.systemFontSize))
    }
}
#endif
