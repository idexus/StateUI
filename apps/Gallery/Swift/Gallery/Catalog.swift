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
                summary: "How this library remembers, skips and identifies things.",
                icon: ImageSource(light: "nav_fundamentals.png", dark: "nav_fundamentals_dark.png"),
                card: ImageSource("cat_fundamentals.png"),
                samples: [
                    Sample(BuilderSample()),
                    Sample(MemoSample()),
                    Sample(RebuildSample()),
                    Sample(IdentitySample()),
                    Sample(StyleSample()),
                    Sample(VisualStateSample()),
                    Sample(WindowSample()),
                    Sample(LifecycleSample(events: windowEvents)),
                    Sample(TitleBarSample()),
                ]),

            SampleGroup(
                route: "state",
                title: "State",
                summary: "Everything an author holds - a value you write, or a control you call.",
                icon: ImageSource(light: "nav_state.png", dark: "nav_state_dark.png"),
                card: ImageSource("cat_state.png"),
                samples: [
                    Sample(StateSample()),
                    Sample(PersistentStateSample()),
                    Sample(StateClassSample()),
                    Sample(ControlStateSample()),
                    Sample(ConcurrentStateSample()),
                    Sample(WatchedFlightSample()),
                    Sample(OnChangedSample()),
                ]),

            SampleGroup(
                route: "environment",
                title: "Environment",
                summary: "What the host knows - provided to every view by "
                    + "type, updated as it changes.",
                icon: ImageSource(light: "nav_environment.png", dark: "nav_environment_dark.png"),
                card: ImageSource("cat_environment.png"),
                samples: [
                    Sample(EnvironmentSample()),
                    Sample(BatterySample()),
                    Sample(ConnectivitySample()),
                    Sample(DeviceDisplaySample()),
                    Sample(LocaleInfoSample()),
                    Sample(DeviceInfoSample()),
                    Sample(AppThemeSample()),
                    Sample(WindowPhaseSample()),
                ]),

            SampleGroup(
                route: "animation",
                title: "Animation",
                summary: "Moving a view that is already on screen, and waiting for it.",
                icon: ImageSource(light: "nav_animation.png", dark: "nav_animation_dark.png"),
                card: ImageSource("cat_animation.png"),
                samples: [
                    Sample(MotionSample()),
                    Sample(AnimationSample()),
                    Sample(AnimatedPropertySample()),
                    Sample(AnimatedInputSample()),
                    Sample(ConcurrentAnimationSample()),
                    Sample(AnalogClockSample()),
                    Sample(DrivenSample()),
                    Sample(DrivenTextSample()),
                ]),

            SampleGroup(
                route: "gestures",
                title: "Gestures",
                summary: "Every recognizer MAUI has, on any view that wants one.",
                icon: ImageSource(light: "nav_gestures.png", dark: "nav_gestures_dark.png"),
                card: ImageSource("cat_gestures.png"),
                samples: [
                    Sample(TapSample()),
                    Sample(SwipeSample()),
                    Sample(PanSample()),
                    Sample(PinchSample()),
                    Sample(PointerSample()),
                    Sample(DragAndDropSample()),
                    Sample(TouchThroughSample()),
                ]),

            SampleGroup(
                route: "basicInput",
                title: "Basic input",
                summary: "The things you tap, type in and drag.",
                icon: ImageSource(light: "nav_input.png", dark: "nav_input_dark.png"),
                card: ImageSource("cat_basicinput.png"),
                samples: [
                    Sample(ButtonSample()),
                    Sample(ImageButtonSample()),
                    Sample(EntrySample()),
                    Sample(EditorSample()),
                    Sample(SearchBarSample()),
                    Sample(KeyboardSample()),
                    Sample(SwitchSample()),
                    Sample(CheckBoxSample()),
                    Sample(RadioButtonSample()),
                    Sample(SliderSample()),
                    Sample(StepperSample()),
                    Sample(PickerSample()),
                ]),

            SampleGroup(
                route: "text",
                title: "Text",
                summary: "Showing words, and the properties MAUI puts on them.",
                icon: ImageSource(light: "nav_text.png", dark: "nav_text_dark.png"),
                card: ImageSource("cat_text.png"),
                samples: [
                    Sample(LabelSample()),
                    Sample(TextSpanSample()),
                ]),

            SampleGroup(
                route: "dateTime",
                title: "Date & time",
                summary: "Days, clocks and countdowns - asked of the host, "
                    + "or ticked by a plain Swift task.",
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
                route: "status",
                title: "Status",
                summary: "Saying that something is happening, how far along it is - "
                    + "and asking before it does.",
                icon: ImageSource(light: "nav_status.png", dark: "nav_status_dark.png"),
                card: ImageSource("cat_status.png"),
                samples: [
                    Sample(ActivityIndicatorSample()),
                    Sample(ProgressBarSample()),
                    Sample(DialogsSample()),
                ]),

            SampleGroup(
                route: "collections",
                title: "Collections",
                summary: "Many items, by this library's own list - which describes only "
                    + "the rows that can be seen.",
                icon: ImageSource(light: "nav_collections.png", dark: "nav_collections_dark.png"),
                card: ImageSource("cat_collections.png"),
                samples: [
                    Sample(CollectionViewSample()),
                    Sample(ManyItemsSample()),
                    Sample(RowSizingSample()),
                    Sample(RowStateSample()),
                    Sample(IncrementalLoadSample()),
                    Sample(SelectionSample()),
                    Sample(GroupingSample()),
                    Sample(SwipeRowsSample()),
                    Sample(GalleryViewSample()),
                    Sample(IndicatorViewSample()),
                    Sample(RefreshViewSample()),
                    Sample(SwipeViewSample()),
                ]),

            SampleGroup(
                route: "layout",
                title: "Layout",
                summary: "Arranging views, and drawing the space between them.",
                icon: ImageSource(light: "nav_layout.png", dark: "nav_layout_dark.png"),
                card: ImageSource("cat_layout.png"),
                samples: [
                    Sample(StackLayoutSample()),
                    Sample(GridSample()),
                    Sample(AbsoluteLayoutSample()),
                    Sample(FlexLayoutSample()),
                    Sample(ScrollViewSample()),
                    Sample(BorderSample()),
                    Sample(BoxViewSample()),
                    Sample(SizingSample()),
                    Sample(TransformSample()),
                    Sample(FlowDirectionSample()),
                    Sample(FrameReaderSample()),
                    Sample(LivingLayoutSample()),
                    Sample(RemovingRowSample()),
                    Sample(PlacedSample()),
                ]),

            SampleGroup(
                route: "shapes",
                title: "Shapes",
                summary: "Outlines, gradients and a canvas - drawn rather than laid out.",
                icon: ImageSource(light: "nav_shapes.png", dark: "nav_shapes_dark.png"),
                card: ImageSource("cat_shapes.png"),
                samples: [
                    Sample(ShapesSample()),
                    Sample(BrushSample()),
                    Sample(GraphicsViewSample()),
                ]),

            SampleGroup(
                route: "media",
                title: "Media",
                summary: "Pictures from the app's resources, a page of the web, and the world.",
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
                summary: "The stack, the tabs and the menu - three pages, and the state "
                    + "that arranges them.",
                icon: ImageSource(light: "nav_shell.png", dark: "nav_shell_dark.png"),
                card: ImageSource("cat_navigation.png"),
                samples: [
                    Sample(NavigationSample(nav: nav)),
                    Sample(ModalSample(nav: nav)),
                    Sample(MultiWindowSample(nav: nav)),
                    Sample(TabsSample(nav: nav)),
                    Sample(SearchSample(nav: nav)),
                    Sample(ToolbarSample()),
                    Sample(ContextMenuSample()),
                    Sample(FlyoutSample(nav: nav, listsHiddenRow: listsHiddenRow)),
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
