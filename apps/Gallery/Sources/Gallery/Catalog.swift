// Everything the gallery shows, in one list.
//
// THIS IS THE FILE TO EDIT when a sample is added. Write the sample under
// Samples/<Group>/, name it here, and it appears on the home page, on its
// group's page and behind its own route - nothing else knows it exists.
//
// A new GROUP is a function of its own below, `<route>Group`, named in `init`,
// plus an icon and a card picture in Resources/Images - a function a group, so
// a debug build's frame stays small. The menu, the sections and the home page
// are all built from this list.

import StateUI

/// The samples, grouped as a user would look for them.
///
/// Built once per gallery and kept by `KeptCatalog`, where everything else that
/// describes the interface is built again on every render. The examples inside
/// are not built until a page shows one, and each keeps its own `@State` for as
/// long as its gallery lives.
///
/// What is threaded through is the GALLERY's own state - one gallery's, a second
/// gallery building a catalog of its own: where it is (`nav` - see
/// Gallery/Navigation.swift), what it looks like, what its window's chrome
/// says, and its window's lifecycle log. The samples that move the gallery or
/// change its look are handed the means to.
@MainActor
final class Catalog {
    let groups: [SampleGroup]

    init(
        nav: Navigation,
        style: SessionStyle,
        bar: WindowBarState,
        log: WindowLog
    ) {
        var groups: [SampleGroup] = [
            Self.fundamentalsGroup(nav: nav, style: style, bar: bar, log: log),
            Self.drivenGroup(nav: nav, style: style, bar: bar, log: log),
            Self.stateGroup(nav: nav, style: style, bar: bar, log: log),
            Self.animationGroup(nav: nav, style: style, bar: bar, log: log),
            Self.basicInputGroup(nav: nav, style: style, bar: bar, log: log),
            Self.textGroup(nav: nav, style: style, bar: bar, log: log),
            Self.layoutGroup(nav: nav, style: style, bar: bar, log: log),
            Self.layoutEngineGroup(nav: nav, style: style, bar: bar, log: log),
            Self.stylesGroup(nav: nav, style: style, bar: bar, log: log),
            Self.shapesGroup(nav: nav, style: style, bar: bar, log: log),
            Self.collectionsGroup(nav: nav, style: style, bar: bar, log: log),
            Self.gesturesGroup(nav: nav, style: style, bar: bar, log: log),
            Self.mediaGroup(nav: nav, style: style, bar: bar, log: log),
            Self.navigationGroup(nav: nav, style: style, bar: bar, log: log),
            Self.sceneGroup(nav: nav, style: style, bar: bar, log: log),
            Self.environmentGroup(nav: nav, style: style, bar: bar, log: log),
            Self.dateTimeGroup(nav: nav, style: style, bar: bar, log: log),
        ]

        #if APPKIT || UIKIT || ANDROID || WINUI || GTK || WEB
        // Calling the host, hearing from it, and a control the application registers with it - each described like
        // the library's own: one contract, one `View`, and the host's half beside the head, in Platforms/<host>.
        groups.append(
            SampleGroup(
                route: InteropHost.key + "Interop",
                title: InteropHost.name + " interop",
                summary: "Calling the host, hearing from it, and a control the app registers.",
                icon: ImageSource(light: "nav_interop.png", dark: "nav_interop_dark.png"),
                card: ImageSource("cat_interop.png"),
                samples: [
                    Sample(InteropActsSample()),
                    Sample(InteropEventsSample()),
                    Sample(InteropControlSample()),
                ]))
        #endif

        self.groups = groups
    }

    /// The group at `fundamentals`.
    private static func fundamentalsGroup(
        nav: Navigation, style: SessionStyle, bar: WindowBarState, log: WindowLog
    ) -> SampleGroup {
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
                Sample(LifetimeSample()),
                Sample(ComplaintsSample()),
                Sample(SameInputsSample()),
            ])
    }

    /// The group at `driven`.
    private static func drivenGroup(
        nav: Navigation, style: SessionStyle, bar: WindowBarState, log: WindowLog
    ) -> SampleGroup {
        SampleGroup(
            route: "driven",
            title: "Driven values",
            summary: "The second layer: a value handed on with $ and carried by the "
                + "host on its own frames, engines following it with nothing described.",
            icon: ImageSource(light: "nav_driven.png", dark: "nav_driven_dark.png"),
            card: ImageSource("cat_driven.png"),
            samples: [
                Sample(BindingReaderSample()),
                Sample(BoundPropertiesSample()),
                Sample(DrivenSample()),
                Sample(EngineSample()),
                Sample(DrivenReadingSample()),
            ])
    }

    /// The group at `state`.
    private static func stateGroup(
        nav: Navigation, style: SessionStyle, bar: WindowBarState, log: WindowLog
    ) -> SampleGroup {
        SampleGroup(
            route: "state",
            title: "Using state",
            summary: "The rest of what an author holds - a control you aim an "
                + "act at, a class, a value kept across launches, a cadence, "
                + "writes from many tasks at once, and what a press does while the "
                + "last still runs.",
            icon: ImageSource(light: "nav_state.png", dark: "nav_state_dark.png"),
            card: ImageSource("cat_state.png"),
            samples: [
                Sample(OnChangedSample()),
                Sample(AimSample()),
                Sample(StateClassSample()),
                Sample(PropertyReadsSample()),
                Sample(PersistentStateSample()),
                Sample(PacedStateSample()),
                Sample(ConcurrentStateSample()),
                Sample(MainQueueSample()),
                Sample(GateSample()),
            ])
    }

    /// The group at `animation`.
    private static func animationGroup(
        nav: Navigation, style: SessionStyle, bar: WindowBarState, log: WindowLog
    ) -> SampleGroup {
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
            ] + Self.drawnByTheHost)
    }

    /// The group at `basicInput`.
    private static func basicInputGroup(
        nav: Navigation, style: SessionStyle, bar: WindowBarState, log: WindowLog
    ) -> SampleGroup {
        SampleGroup(
            route: "basicInput",
            title: "Controls",
            summary: "Button, Switch, CheckBox, Slider, Stepper and Picker, "
                + "the spinner and the bar that show work, and what a "
                + "control says about itself; text fields are under Text & typing.",
            icon: ImageSource(light: "nav_input.png", dark: "nav_input_dark.png"),
            card: ImageSource("cat_basicinput.png"),
            samples: [
                Sample(ButtonSample()),
                Sample(ButtonRoleSample()),
                Sample(ButtonMenuSample()),
                Sample(IconButtonSample()),
                Sample(SwitchSample()),
                Sample(CheckBoxSample()),
                Sample(SliderSample()),
                Sample(StepperSample()),
                Sample(PickerSample()),
                Sample(ProgressBarSample()),
                Sample(ActivityIndicatorSample()),
                Sample(SemanticsSample()),
                Sample(TooltipSample()),
                Sample(ShortcutSample()),
                Sample(KeyPressSample()),
            ])
    }

    /// The group at `text`.
    private static func textGroup(
        nav: Navigation, style: SessionStyle, bar: WindowBarState, log: WindowLog
    ) -> SampleGroup {
        SampleGroup(
            route: "text",
            title: "Text & typing",
            summary: "Words shown and words typed - a Text and its spans, TextField, "
                + "TextEditor, SearchField on the page rather than in the navigation "
                + "bar, and giving the keyboard back.",
            icon: ImageSource(light: "nav_text.png", dark: "nav_text_dark.png"),
            card: ImageSource("cat_text.png"),
            samples: [
                Sample(TextSample()),
                Sample(TextStyleSample()),
                Sample(SelectableTextSample()),
                Sample(TextSpanSample()),
                Sample(TextFieldSample()),
                Sample(NextFieldSample()),
                Sample(TextEditorSample()),
                Sample(SearchFieldSample()),
                Sample(KeyboardSample()),
            ])
    }

    /// The group at `layout`.
    private static func layoutGroup(
        nav: Navigation, style: SessionStyle, bar: WindowBarState, log: WindowLog
    ) -> SampleGroup {
        SampleGroup(
            route: "layout",
            title: "Layout",
            summary: "Stacks, grids, layers, scrolling, sizing and transforms.",
            icon: ImageSource(light: "nav_layout.png", dark: "nav_layout_dark.png"),
            card: ImageSource("cat_layout.png"),
            samples: [
                Sample(StackLayoutSample()),
                Sample(FillSample()),
                Sample(GridSample()),
                Sample(ZStackSample()),
                Sample(ScrollViewSample()),
                Sample(SizingSample()),
                Sample(OutlineSample()),
                Sample(SafeAreaSample()),
                Sample(TransformSample()),
                Sample(LayoutDirectionSample()),
                Sample(GeometryReaderSample()),
                Sample(LivingLayoutSample()),
                Sample(RemovingRowSample()),
            ])
    }

    /// The group at `layoutEngine`.
    private static func layoutEngineGroup(
        nav: Navigation, style: SessionStyle, bar: WindowBarState, log: WindowLog
    ) -> SampleGroup {
        SampleGroup(
            route: "layoutEngine",
            title: "Layout Engine",
            summary: "Views placed by arithmetic of your own, worked out from a phase the hand or the "
                + "program moves: a ring, a deck, pages of icons, a table panned, pinched and turned.",
            icon: ImageSource(light: "nav_layoutengine.png", dark: "nav_layoutengine_dark.png"),
            card: ImageSource("cat_layoutengine.png"),
            samples: [
                Sample(LayoutEngineSample()),
                Sample(LayoutPhaseSample()),
                Sample(LayoutAxesSample()),
                Sample(LayoutKeyframesSample()),
                Sample(ChangingDeckSample()),
                Sample(HomeScreenSample()),
                Sample(AppSwitcherSample()),
                Sample(TwoFingersSample()),
                Sample(LightTableSample()),
            ])
    }

    /// The group at `styles`.
    private static func stylesGroup(
        nav: Navigation, style: SessionStyle, bar: WindowBarState, log: WindowLog
    ) -> SampleGroup {
        SampleGroup(
            route: "styles",
            title: "Styles",
            summary: "How a control looks - one style worn by every control of a "
                + "type, how it looks held down or disabled, the theme it "
                + "answers light and dark, what a surface is made of, and the "
                + "look the gallery wears.",
            icon: ImageSource(light: "nav_styles.png", dark: "nav_styles_dark.png"),
            card: ImageSource("cat_styles.png"),
            samples: [
                Sample(StyleSample()),
                Sample(VisualStateSample()),
                Sample(AppThemeSample()),
                Sample(MaterialsSample()),
                Sample(AppearanceSample(style: style)),
            ])
    }

    /// The group at `shapes`.
    private static func shapesGroup(
        nav: Navigation, style: SessionStyle, bar: WindowBarState, log: WindowLog
    ) -> SampleGroup {
        SampleGroup(
            route: "shapes",
            title: "Shapes",
            summary: "Outlines, gradients and a canvas - seven shapes, brushes on any "
                + "view at all, and drawing instructions the host carries out.",
            icon: ImageSource(light: "nav_shapes.png", dark: "nav_shapes_dark.png"),
            card: ImageSource("cat_shapes.png"),
            samples: [
                Sample(ShapesSample()),
                Sample(BrushSample()),
                Sample(CanvasSample()),
            ])
    }

    /// The group at `collections`.
    private static func collectionsGroup(
        nav: Navigation, style: SessionStyle, bar: WindowBarState, log: WindowLog
    ) -> SampleGroup {
        SampleGroup(
            route: "collections",
            title: "Items and Cards",
            summary: "The platform's own lists of items, cards swiped through one at a time, and the dots "
                + "that say which one shows.",
            icon: ImageSource(light: "nav_collections.png", dark: "nav_collections_dark.png"),
            card: ImageSource("cat_collections.png"),
            samples: [
                Sample(ItemsViewSample()),
                Sample(ChoosingItemsSample()),
                Sample(LoadingItemsSample()),
                Sample(RefreshSample()),
                Sample(ItemActionsSample()),
                Sample(GalleryViewSample()),
                Sample(PositionIndicatorSample()),
            ])
    }

    /// The group at `gestures`.
    private static func gesturesGroup(
        nav: Navigation, style: SessionStyle, bar: WindowBarState, log: WindowLog
    ) -> SampleGroup {
        SampleGroup(
            route: "gestures",
            title: "Gestures",
            summary: "A gesture on any view that wants one - a tap, a drag, a swipe, "
                + "a pinch, a pointer, and carrying something from one view to another.",
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
            ])
    }

    /// The group at `media`.
    private static func mediaGroup(
        nav: Navigation, style: SessionStyle, bar: WindowBarState, log: WindowLog
    ) -> SampleGroup {
        SampleGroup(
            route: "media",
            title: "Media",
            summary: "Pictures from the app's resources, the platform's icons, a page of "
                + "the web, and the world on a map.",
            icon: ImageSource(light: "nav_media.png", dark: "nav_media_dark.png"),
            card: ImageSource("cat_media.png"),
            samples: [
                Sample(ImageSample()),
                Sample(IconSample()),
                Sample(WebViewSample()),
                Sample(MapSample()),
            ])
    }

    /// The group at `navigation`.
    private static func navigationGroup(
        nav: Navigation, style: SessionStyle, bar: WindowBarState, log: WindowLog
    ) -> SampleGroup {
        SampleGroup(
            route: "navigation",
            title: "Navigation",
            summary: "Moving between pages - the stack, the tabs and the split view; a "
                + "modal, an alert, a file dialog, the clipboard, sharing, a toolbar, a menu and a popover over them; "
                + "and a search field in the navigation bar.",
            icon: ImageSource(light: "nav_shell.png", dark: "nav_shell_dark.png"),
            card: ImageSource("cat_navigation.png"),
            samples: [
                Sample(NavigationSample(nav: nav)),
                Sample(TabsSample(nav: nav)),
                Sample(SplitViewSample(nav: nav)),
                Sample(ModalSample(nav: nav)),
                Sample(DialogsSample()),
                Sample(FilesSample()),
                Sample(ClipboardSample()),
                Sample(ShareSample()),
                Sample(ToolbarSample()),
                Sample(ToolbarLayersSample(nav: nav)),
                Sample(MenuBarSample()),
                Sample(ContextMenuSample()),
                Sample(PopoverSample()),
                Sample(SearchSample(nav: nav)),
            ])
    }

    /// The group at `scene`.
    private static func sceneGroup(
        nav: Navigation, style: SessionStyle, bar: WindowBarState, log: WindowLog
    ) -> SampleGroup {
        SampleGroup(
            route: "scene",
            title: "Scene",
            summary: "A scene and the frame around its pages - its windows and their bar, what it lays over "
                + "them, and what it says as the app comes and goes.",
            icon: ImageSource(light: "nav_windows.png", dark: "nav_windows_dark.png"),
            card: ImageSource("cat_windows.png"),
            samples: Self.openingWindows([Sample(WindowSample())]) + [
                Sample(WindowBarSample(bar: bar)),
            ] + Self.openingWindows([Sample(MultiWindowSample(style: style)), Sample(ScenesSample())]) + [
                Sample(WindowOverlaySample(nav: nav)),
                Sample(LifecycleSample(log: log)),
                Sample(WindowPhaseSample()),
            ])
    }

    /// The group at `environment`.
    private static func environmentGroup(
        nav: Navigation, style: SessionStyle, bar: WindowBarState, log: WindowLog
    ) -> SampleGroup {
        SampleGroup(
            route: "environment",
            title: "Environment",
            summary: "What the host knows - the device, the screen, the locale, the "
                + "network and a request through it, and the battery - the application's session, an object "
                + "of your own provided above and resolved below by type, and a document "
                + "in its own language; the theme is under Styles, the scene's and the "
                + "window's sessions under Scene.",
            icon: ImageSource(light: "nav_environment.png", dark: "nav_environment_dark.png"),
            card: ImageSource("cat_environment.png"),
            samples: [
                Sample(EnvironmentSample()),
                Sample(DeviceInfoSample()),
                Sample(DeviceDisplaySample()),
                Sample(LocaleInfoSample()),
                Sample(LocalizationSample()),
                Sample(ConnectivitySample()),
                Sample(HTTPRequestSample()),
                Sample(BatterySample()),
                Sample(AccessibilitySettingsSample()),
                Sample(PlatformSupportSample()),
                Sample(ApplicationSessionSample()),
            ])
    }

    /// The group at `dateTime`.
    private static func dateTimeGroup(
        nav: Navigation, style: SessionStyle, bar: WindowBarState, log: WindowLog
    ) -> SampleGroup {
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
            ] + Self.foundationProbe)
    }

    /// What Foundation answers of the clock and the calendar, where the application links Foundation: the Web links
    /// none, so its module stays small.
    private static var foundationProbe: [Sample] {
        #if WEB
        []
        #else
        [Sample(FoundationProbeSample())]
        #endif
    }

    /// `samples` on the hosts that open the application's windows: a page on the Web stands in the one browser
    /// window it was opened in, which it neither sizes nor opens again.
    private static func openingWindows(_ samples: [Sample]) -> [Sample] {
        #if WEB
        []
        #else
        samples
        #endif
    }

    /// The animation the host draws on the GPU. Every host draws it in its own way; a build for no host - the
    /// gallery's own tests - has nothing to draw it with, so it declares no cube.
    private static var drawnByTheHost: [Sample] {
        #if APPKIT || UIKIT || ANDROID || WINUI || GTK || WEB
        [Sample(Cube3DSample())]
        #else
        []
        #endif
    }

    /// How many samples `device` lists - the home page's count, so it agrees with
    /// what the group pages show.
    @MainActor
    func sampleCount(on device: Device) -> Int {
        groups.reduce(0) { $0 + $1.shown(on: device).count }
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

/// Where a gallery keeps its catalog.
///
/// A class for two reasons, and both are measured. It is what makes "built
/// once" possible at all - the scene is a value, and a value cannot fill a
/// slot in itself as it hands one out. And the state walk that pairs a rebuilt
/// view's `@State` with the storage it had last render STOPS at a class, which
/// is what keeps a hundred samples out of a walk that runs on every render of
/// the window holding them: on this catalog that walk is 0.03 ms, where it
/// would be 7.95.
///
/// Nothing is lost by stopping it. A sample's state is kept by the SAMPLE,
/// living as long as its gallery does, rather than by a fresh copy of it
/// adopting the older one's storage every render, and the page showing a
/// sample drives the one it holds.
@MainActor
final class KeptCatalog {
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
