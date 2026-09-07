// Everything the gallery shows, in one list.
//
// THIS IS THE FILE TO EDIT when a sample is added. Write the sample under
// Samples/<Group>/, name it here, and it appears on the home page, on its
// group's page and behind its own route - nothing else knows it exists.
//
// A new GROUP is a `SampleGroup(…)` below plus an icon in Resources/Images. The
// menu, the sections and the home page are all built from this list.

import StateUI

/// The samples, grouped as a reader would look for them.
///
/// Rebuilt on every render, like everything else that describes the interface.
/// Building it costs a few structs; the examples inside are not built until a
/// page shows one - and each owns its `@State`, carried across the rebuilds by
/// the pages that hold this catalog.
///
/// What is threaded through is the APPLICATION's own state: where the gallery is
/// (`nav` - see Gallery/Navigation.swift), whether the menu lists its hidden row,
/// and the window's event log. Three samples move the application, so three
/// samples are handed the means to.
final class Catalog {
    let groups: [SampleGroup]

    init(
        nav: Navigation,
        listsHiddenRow: Binding<Bool>,
        windowEvents: Binding<[String]>
    ) {
        groups = [
            SampleGroup(
                route: "fundamentals",
                title: "Fundamentals",
                summary: "One declaration, and the rule the whole library is written on: "
                    + "whoever reads a value is rebuilt when it changes.",
                icon: ImageSource(light: "nav_fundamentals.png", dark: "nav_fundamentals_dark.png"),
                card: ImageSource("cat_fundamentals.png"),
                samples: [
                    Sample(StateSample()),
                    Sample(RebuildSample()),
                    Sample(TwoLayersSample()),
                    Sample(ReaderSample()),
                    Sample(ConverterSample()),
                    Sample(BuilderSample()),
                    Sample(IdentitySample()),
                    Sample(MemoSample()),
                ]),

            SampleGroup(
                route: "driven",
                title: "Driven values",
                summary: "The second layer: a value handed on with $ and carried by the "
                    + "host on its own frames - engines follow it and nothing is "
                    + "described. A layout placed by one is under Layout, as "
                    + "PlacedLayout.",
                icon: ImageSource(light: "nav_driven.png", dark: "nav_driven_dark.png"),
                card: ImageSource("cat_driven.png"),
                samples: [
                    Sample(BindingReaderSample()),
                    Sample(BoundPropertiesSample()),
                    Sample(DrivenSample()),
                    Sample(DrivenTextSample()),
                    Sample(DrivenReadingSample()),
                ]),

            SampleGroup(
                route: "state",
                title: "Using state",
                summary: "The rest of what an author holds - a control you focus or "
                    + "scroll to, a class, a value kept across launches, a cadence, "
                    + "and writes from many tasks at once.",
                icon: ImageSource(light: "nav_state.png", dark: "nav_state_dark.png"),
                card: ImageSource("cat_state.png"),
                samples: [
                    Sample(OnChangedSample()),
                    Sample(ControlStateSample()),
                    Sample(StateClassSample()),
                    Sample(PersistentStateSample()),
                    Sample(PacedStateSample()),
                    Sample(ConcurrentStateSample()),
                ]),

            SampleGroup(
                route: "animation",
                title: "Animation",
                summary: "A value that changes travels to it - at a length, on a spring, "
                    + "or not at all - and journeys started, overlapped and awaited.",
                icon: ImageSource(light: "nav_animation.png", dark: "nav_animation_dark.png"),
                card: ImageSource("cat_animation.png"),
                samples: [
                    Sample(MotionSample()),
                    Sample(AnimationSample()),
                    Sample(AnimatedPropertySample()),
                    Sample(AnimatedInputSample()),
                    Sample(ConcurrentAnimationSample()),
                    Sample(AnalogClockSample()),
                ]),

            SampleGroup(
                route: "basicInput",
                title: "Controls",
                summary: "Button, Switch, CheckBox, RadioButton, Slider, Stepper and "
                    + "Picker - and the spinner and the bar that show work; text "
                    + "fields are under Text & typing.",
                icon: ImageSource(light: "nav_input.png", dark: "nav_input_dark.png"),
                card: ImageSource("cat_basicinput.png"),
                samples: [
                    Sample(ButtonSample()),
                    Sample(ImageButtonSample()),
                    Sample(SwitchSample()),
                    Sample(CheckBoxSample()),
                    Sample(RadioButtonSample()),
                    Sample(SliderSample()),
                    Sample(StepperSample()),
                    Sample(PickerSample()),
                    Sample(ProgressBarSample()),
                    Sample(ActivityIndicatorSample()),
                ]),

            SampleGroup(
                route: "text",
                title: "Text & typing",
                summary: "Words shown and words typed - a Label and its spans, Entry, "
                    + "Editor, SearchBar on the page rather than in the navigation "
                    + "bar, and giving the keyboard back.",
                icon: ImageSource(light: "nav_text.png", dark: "nav_text_dark.png"),
                card: ImageSource("cat_text.png"),
                samples: [
                    Sample(LabelSample()),
                    Sample(TextSpanSample()),
                    Sample(EntrySample()),
                    Sample(EditorSample()),
                    Sample(SearchBarSample()),
                    Sample(KeyboardSample()),
                ]),

            SampleGroup(
                route: "layout",
                title: "Layout",
                summary: "Stacks, grids, FlexLayout and AbsoluteLayout; PlacedLayout, "
                    + "which puts each view where your own arithmetic says; sizing, "
                    + "scrolling, borders and transforms; measuring a view's frame, "
                    + "laying out right to left, and what slides when a row is "
                    + "inserted or removed.",
                icon: ImageSource(light: "nav_layout.png", dark: "nav_layout_dark.png"),
                card: ImageSource("cat_layout.png"),
                samples: [
                    Sample(StackLayoutSample()),
                    Sample(GridSample()),
                    Sample(FlexLayoutSample()),
                    Sample(AbsoluteLayoutSample()),
                    Sample(PlacedSample()),
                    Sample(ScrollViewSample()),
                    Sample(SizingSample()),
                    Sample(BorderSample()),
                    Sample(BoxViewSample()),
                    Sample(TransformSample()),
                    Sample(FlowDirectionSample()),
                    Sample(FrameReaderSample()),
                    Sample(LivingLayoutSample()),
                    Sample(RemovingRowSample()),
                ]),

            SampleGroup(
                route: "styles",
                title: "Styles",
                summary: "How a control looks - one style worn by every control of a "
                    + "type, how it looks held down or disabled, and the theme it "
                    + "answers light and dark.",
                icon: ImageSource(light: "nav_styles.png", dark: "nav_styles_dark.png"),
                card: ImageSource("cat_styles.png"),
                samples: [
                    Sample(StyleSample()),
                    Sample(VisualStateSample()),
                    Sample(AppThemeSample()),
                ]),

            SampleGroup(
                route: "shapes",
                title: "Shapes",
                summary: "Outlines, gradients and a canvas - the seven shapes MAUI "
                    + "draws, brushes on any view at all, and drawing instructions "
                    + "the host carries out.",
                icon: ImageSource(light: "nav_shapes.png", dark: "nav_shapes_dark.png"),
                card: ImageSource("cat_shapes.png"),
                samples: [
                    Sample(ShapesSample()),
                    Sample(BrushSample()),
                    Sample(GraphicsViewSample()),
                ]),

            SampleGroup(
                route: "collections",
                title: "Lists & cards",
                summary: "Many items by this library's own CollectionView - only the "
                    + "rows that can be seen are described - with selection, "
                    + "grouping, SwipeView, RefreshView, and GalleryView with its "
                    + "IndicatorView dots.",
                icon: ImageSource(light: "nav_collections.png", dark: "nav_collections_dark.png"),
                card: ImageSource("cat_collections.png"),
                samples: [
                    Sample(CollectionViewSample()),
                    Sample(ManyItemsSample()),
                    Sample(RowSizingSample()),
                    Sample(SelectionSample()),
                    Sample(GroupingSample()),
                    Sample(RowStateSample()),
                    Sample(IncrementalLoadSample()),
                    Sample(SwipeRowsSample()),
                    Sample(SwipeViewSample()),
                    Sample(RefreshViewSample()),
                    Sample(GalleryViewSample()),
                    Sample(IndicatorViewSample()),
                ]),

            SampleGroup(
                route: "gestures",
                title: "Gestures",
                summary: "Every recognizer MAUI has, on any view that wants one - a tap, "
                    + "a drag, a swipe, a pinch, a pointer, and carrying something "
                    + "from one view to another.",
                icon: ImageSource(light: "nav_gestures.png", dark: "nav_gestures_dark.png"),
                card: ImageSource("cat_gestures.png"),
                samples: [
                    Sample(TapSample()),
                    Sample(PanSample()),
                    Sample(SwipeSample()),
                    Sample(PinchSample()),
                    Sample(PointerSample()),
                    Sample(DragAndDropSample()),
                    Sample(TouchThroughSample()),
                ]),

            SampleGroup(
                route: "media",
                title: "Media",
                summary: "Pictures from the app's resources, a page of the web, and the "
                    + "world on a map.",
                icon: ImageSource(light: "nav_media.png", dark: "nav_media_dark.png"),
                card: ImageSource("cat_media.png"),
                samples: [
                    Sample(ImageSample()),
                    Sample(WebViewSample()),
                    Sample(MapSample()),
                ]),

            SampleGroup(
                route: "navigation",
                title: "Navigation",
                summary: "Moving between pages - the stack, the tabs and the flyout; a "
                    + "modal, an alert, a toolbar and a menu over them; and a search "
                    + "field in the navigation bar.",
                icon: ImageSource(light: "nav_shell.png", dark: "nav_shell_dark.png"),
                card: ImageSource("cat_navigation.png"),
                samples: [
                    Sample(NavigationSample(nav: nav)),
                    Sample(TabsSample(nav: nav)),
                    Sample(FlyoutSample(nav: nav, listsHiddenRow: listsHiddenRow)),
                    Sample(ModalSample(nav: nav)),
                    Sample(DialogsSample()),
                    Sample(ToolbarSample()),
                    Sample(ContextMenuSample()),
                    Sample(SearchSample(nav: nav)),
                ]),

            SampleGroup(
                route: "windows",
                title: "Windows",
                summary: "The frame around the pages - what a window is called, where it "
                    + "opens, its title bar, more than one of them, and what it says "
                    + "as the app comes and goes.",
                icon: ImageSource(light: "nav_windows.png", dark: "nav_windows_dark.png"),
                card: ImageSource("cat_windows.png"),
                samples: [
                    Sample(WindowSample()),
                    Sample(TitleBarSample()),
                    Sample(MultiWindowSample(nav: nav)),
                    Sample(LifecycleSample(events: windowEvents)),
                    Sample(WindowPhaseSample()),
                ]),

            SampleGroup(
                route: "environment",
                title: "Environment",
                summary: "What the host knows - the device, the screen, the locale, the "
                    + "network and the battery - provided above and resolved below by "
                    + "type; the theme is under Styles.",
                icon: ImageSource(light: "nav_environment.png", dark: "nav_environment_dark.png"),
                card: ImageSource("cat_environment.png"),
                samples: [
                    Sample(EnvironmentSample()),
                    Sample(DeviceInfoSample()),
                    Sample(DeviceDisplaySample()),
                    Sample(LocaleInfoSample()),
                    Sample(ConnectivitySample()),
                    Sample(BatterySample()),
                ]),

            SampleGroup(
                route: "dateTime",
                title: "Date & time",
                summary: "Choosing a day or a time, what the host answers about the "
                    + "clock and the zone, and three ways to repeat work on a timer "
                    + "without blocking anything - Ticker, Poll and Task.sleep.",
                icon: ImageSource(light: "nav_datetime.png", dark: "nav_datetime_dark.png"),
                card: ImageSource("cat_datetime.png"),
                samples: [
                    Sample(DatePickerSample()),
                    Sample(TimePickerSample()),
                    Sample(HostTimeSample()),
                    Sample(TickerSample()),
                    Sample(PollSample()),
                    Sample(TaskSleepSample()),
                    Sample(FoundationProbeSample()),
                ]),

            SampleGroup(
                route: "interop",
                title: "C# interop",
                summary: "Calling C#, hearing from it, and controls the app registers - "
                    + "spoken to like the library's own.",
                icon: ImageSource(light: "nav_interop.png", dark: "nav_interop_dark.png"),
                card: ImageSource("cat_interop.png"),
                samples: [
                    Sample(CustomActsSample()),
                    Sample(CustomEventsSample()),
                    Sample(CustomControlSample()),
                    Sample(CustomContainerSample()),
                    Sample(CustomBindingSample()),
                    Sample(CustomStyleSample()),
                    Sample(CustomAnimationSample()),
                ]),
        ]
    }

    /// How many samples a device of `idiom` lists - the home page's count, so
    /// it agrees with what the group pages show.
    func sampleCount(on idiom: DeviceIdiom) -> Int {
        groups.reduce(0) { $0 + $1.shown(on: idiom).count }
    }

    /// The sample behind an id, for the route that pushes one.
    func sample(id: String) -> Sample? {
        for group in groups {
            for sample in group.samples where sample.id == id {
                return sample
            }
        }

        return nil
    }
}

/// Where the application keeps its catalog.
///
/// A class for two reasons, and both are measured. It is what makes "built
/// once" possible at all - the application is a value, and a value cannot fill
/// a slot in itself as it hands one out. And the state walk that pairs a
/// rebuilt view's `@State` with the storage it had last render STOPS at a
/// class, which is what keeps a hundred samples out of a walk that runs on
/// every render of the window holding them: on this catalog, that walk went
/// from 7.95 ms to 0.03 ms.
///
/// Nothing is lost by stopping it. A sample's state is kept by the SAMPLE now
/// living as long as the application does, rather than by a fresh copy of it
/// adopting the older one's storage every render, and the page showing a
/// sample drives the one it holds exactly as it always did.
final class KeptCatalog: @unchecked Sendable {
    private var held: Catalog?

    /// The catalog, built by `make` the first time anybody asks and simply
    /// handed over every time after.
    func catalog(_ make: () -> Catalog) -> Catalog {
        if let held { return held }

        let built = make()
        held = built
        return built
    }
}
