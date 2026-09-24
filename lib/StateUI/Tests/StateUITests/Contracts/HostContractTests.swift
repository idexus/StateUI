// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

/// The native-host contract is closed over StateUI's built-in vocabulary even
/// though applications remain free to declare their own contracts.
final class HostContractTests: XCTestCase {
    func testEveryBuiltInControlPropertyAndEventHasOneOwner() throws {
        let source = try SourceTree.text(in: "Tokens.swift")

        assertCoverage(
            classified: Set(LibraryContracts.elements.map { $0.nodeType.name }),
            declared: declaredNames(of: "NodeType", in: source),
            vocabulary: "NodeType")
        assertCoverage(
            classified: Self.names(of: .property),
            declared: declaredNames(of: "Prop", in: source),
            vocabulary: "Prop")
        assertCoverage(
            classified: Self.names(of: .event),
            declared: declaredNames(of: "Event", in: source),
            vocabulary: "Event")
    }

    /// Page presentation, safe-area layout, backdrop composition, focus
    /// dismissal and navigation-title composition are expressed by their
    /// dedicated StateUI structures. They do not create a second, page-only
    /// vocabulary for capabilities that native hosts do not share.
    func testPageVocabularyContainsOnlySharedCapabilities() throws {
        let source = try SourceTree.text(in: "Tokens.swift")
        let properties = declaredNames(of: "Prop", in: source)
        let pageOnlyAlternatives: Set<String> = [
            "backgroundImageSource",
            "hideSoftInputOnTapped",
            "modalPresentationStyle",
            "navigationPageIconColor",
            "navigationPageTitleIconImageSource",
            "useSafeArea",
        ]

        XCTAssertTrue(
            properties.isDisjoint(with: pageOnlyAlternatives),
            "page-only alternatives remain in the host contract: "
                + properties.intersection(pageOnlyAlternatives).sorted().joined(separator: ", "))
    }

    /// Native page bars share a flat authored color and a foreground color.
    /// A gradient or image remains ordinary view composition instead of a
    /// second background renderer hidden inside every platform adapter.
    func testBarVocabularyContainsOnlyNativeAppearanceCapabilities() throws {
        let tokenSource = try SourceTree.text(in: "Tokens.swift")
        let barSource = try SourceTree.text(in: "BarElement.swift")
        let navigationSource = try SourceTree.text(in: "NavigationStack.swift")
        let tabSource = try SourceTree.text(in: "TabbedView.swift")
        let properties = declaredNames(of: "Prop", in: tokenSource)

        XCTAssertFalse(properties.contains("barBackground"))
        XCTAssertFalse(properties.contains("selectedTabColor"))
        XCTAssertFalse(properties.contains("unselectedTabColor"))
        XCTAssertFalse(barSource.contains("func barBackground("))
        XCTAssertFalse(barSource.contains("func barForegroundColor("))
        XCTAssertTrue(navigationSource.contains("func barForegroundColor("))
        XCTAssertFalse(tabSource.contains("func selectedTabColor("))
        XCTAssertFalse(tabSource.contains("func unselectedTabColor("))
    }

    /// The user owns whether a flyout is open; the native host owns how its
    /// panes adapt and which native gestures are available on that platform.
    func testFlyoutVocabularyDoesNotExposeHostPresentationPolicy() throws {
        let tokenSource = try SourceTree.text(in: "Tokens.swift")
        let vocabularies = try Self.typeSources().map(\.text).joined(separator: "\n")
        let flyoutSource = try SourceTree.text(in: "SplitView.swift")
        let properties = declaredNames(of: "Prop", in: tokenSource)

        XCTAssertFalse(properties.contains("flyoutLayoutBehavior"))
        XCTAssertFalse(properties.contains("isGestureEnabled"))
        XCTAssertFalse(vocabularies.contains("enum FlyoutLayoutBehavior"))
        XCTAssertFalse(flyoutSource.contains("func flyoutLayoutBehavior("))
        XCTAssertFalse(flyoutSource.contains("func isGestureEnabled("))
    }

    /// Stack names stay identical from application source through the typed
    /// host boundary. There is no second layout-shaped spelling to translate
    /// or preserve.
    func testStackVocabularyUsesThePublicStateUISpellings() throws {
        let tokenSource = try SourceTree.text(in: "Tokens.swift")
        let stackSource = try SourceTree.text(in: "StackLayouts.swift")
        let controls = declaredNames(of: "NodeType", in: tokenSource)
        let formerNames = ["VerticalStackLayout", "HorizontalStackLayout"]

        XCTAssertTrue(controls.isSuperset(of: ["VStack", "HStack"]))
        XCTAssertTrue(
            controls.isDisjoint(with: Set(formerNames)),
            "legacy stack names remain in the host contract")
        for name in formerNames {
            XCTAssertFalse(stackSource.contains(name), "\(name) remains in the public API")
        }
    }

    /// The arrangements carry StateUI's own names from application source
    /// through the typed host boundary: a navigation stack, a tabbed view, a
    /// split view with a sidebar. The page-shaped spellings they replaced do
    /// not return.
    func testArrangementVocabularyUsesThePublicStateUISpellings() throws {
        let tokenSource = try SourceTree.text(in: "Tokens.swift")
        let controls = declaredNames(of: "NodeType", in: tokenSource)
        let properties = declaredNames(of: "Prop", in: tokenSource)
        let events = declaredNames(of: "Event", in: tokenSource)
        let formerTypes = ["NavigationPage", "TabbedPage", "FlyoutPage"]

        XCTAssertTrue(controls.isSuperset(of: [
            "NavigationStack", "TabbedView", "SplitView", "TitleView",
        ]))
        XCTAssertTrue(
            controls.isDisjoint(with: Set(formerTypes + ["NavigationPageTitleView"])),
            "page-shaped arrangement names remain in the host contract")
        XCTAssertTrue(
            properties.isDisjoint(with: [
                "isPresented", "navigationPageBackButtonTitle",
                "navigationPageHasBackButton", "navigationPageHasNavigationBar",
            ]),
            "page-shaped arrangement properties remain in the host contract")
        XCTAssertFalse(events.contains("isPresentedChanged"))

        for (path, text) in try SourceTree.allSources() {
            for former in formerTypes {
                XCTAssertFalse(
                    text.contains("struct \(former)"),
                    "\(former) is declared again in \(path)")
            }
        }
    }

    /// A page is what a container shows: every view is one and so is each
    /// arrangement, and nobody declares one by hand. An arrangement is not a
    /// view, so it stands only where a page stands. `ContentPage` does not
    /// return, as a protocol or as a node type.
    func testAPageIsWhatAContainerShows() throws {
        let tokenSource = try SourceTree.text(in: "Tokens.swift")
        let controls = declaredNames(of: "NodeType", in: tokenSource)

        XCTAssertTrue(controls.contains("Page"))
        XCTAssertFalse(controls.contains("ContentPage"), "the page is named twice on the host boundary")

        let path = State<[Int]>([])
        let sidebar = State(false)
        let arrangements: [any Page] = [
            NavigationStack(path.projectedValue) { Label("root") } destination: { _ in Label("page") },
            TabbedView([0, 1]) { _ in Label("tab") },
            SplitView(sidebar.projectedValue) { Label("sidebar") } detail: { Label("detail") },
        ]

        for arrangement in arrangements {
            XCTAssertFalse(
                arrangement is any View,
                "\(type(of: arrangement)) is a view, so it could stand inside content")
        }

        for (path, text) in try SourceTree.allSources() {
            XCTAssertNil(
                text.range(of: "\\bprotocol ContentPage\\b", options: .regularExpression),
                "ContentPage is declared again in \(path)")
        }
    }

    func testDerivedLayoutsAndControlsBelongToStateUI() {
        for type in [
            NodeType.checkBox, .ellipse, .grid,
            .positionIndicator, .line, .path, .polygon, .polyline, .radioButton,
            .rectangle,
        ] {
            XCTAssertEqual(Self.layer(of: type), .stateUI)
        }

        for property in [
            Prop.columns, .gridColumn, .gridColumnSpan, .gridRow,
            .gridRowSpan, .rows,
        ] {
            XCTAssertEqual(Self.layer(of: property), .stateUI)
        }
    }

    func testProtocolNodesRemainStructural() {
        for type in [
            NodeType.application, .scene, .window, .overlay,
        ] {
            XCTAssertEqual(Self.layer(of: type), .structure)
        }
    }

    /// A token nothing writes is a promise no host keeps: `content`,
    /// `isOpaque` and `textType` have no modifier and no realization, and are
    /// no part of the vocabulary. `Composed`, the differ's placeholder for a
    /// composed view, is expanded before anything is sent - the library's own
    /// name, not the host's. None of them returns.
    func testNoTokenPromisesWhatNothingWrites() throws {
        let tokenSource = try SourceTree.text(in: "Tokens.swift")
        let controls = declaredNames(of: "NodeType", in: tokenSource)
        let properties = declaredNames(of: "Prop", in: tokenSource)

        XCTAssertTrue(
            properties.isDisjoint(with: ["content", "isOpaque", "textType"]),
            "a property nothing writes is back in the vocabulary: "
                + properties.intersection(["content", "isOpaque", "textType"]).sorted().joined(separator: ", "))
        XCTAssertFalse(controls.contains("Composed"), "the differ's placeholder is host vocabulary again")
        XCTAssertNil(Self.layer(of: NodeType("Composed")), "the differ's placeholder has a contract again")
    }

    func testProviderSurfaceDoesNotBecomeABaseHostRequirement() {
        XCTAssertEqual(Self.layer(of: NodeType.map), .provider)
        XCTAssertEqual(Self.layer(of: NodeType.pin), .provider)
        XCTAssertEqual(Self.layer(of: Prop.mapType), .provider)
        XCTAssertEqual(Self.layer(of: Prop.region), .provider)
        XCTAssertEqual(Self.layer(of: Event.mapClicked), .provider)
    }

    func testPlatformContractNamesEveryBuiltInTokenAndTargetHost() throws {
        let document = try String(
            contentsOf: SourceTree.repository.appendingPathComponent("docs/platform-contract.md"),
            encoding: .utf8)
        let statusRows = document
            .components(separatedBy: "## Complete host vocabulary")[0]
            .split(separator: "\n")
            .filter { $0.hasPrefix("| ") }
            .joined(separator: "\n")

        assertDocumented(
            LibraryContracts.elements.map { $0.nodeType.name },
            vocabulary: "control",
            in: statusRows)
        assertDocumented(
            Self.names(of: .property).sorted(),
            vocabulary: "property",
            in: statusRows)
        assertDocumented(
            Self.names(of: .event).sorted(),
            vocabulary: "event",
            in: statusRows)

        for host in ["AppKit", "UIKit", "GTK 4", "Android Views", "WinUI 3", "Web"] {
            XCTAssertTrue(document.contains(host), "platform contract does not name \(host)")
        }
        XCTAssertTrue(document.contains("✅ means"), "platform contract does not define completion")
    }

    /// The scroller is the platform's: no grid to settle on, no momentum to
    /// tune and no report step. The tokens that carried them were removed by
    /// decision and do not return.
    func testTheScrollerKeepsNoGridNoMomentumAndNoStep() throws {
        let tokenSource = try SourceTree.text(in: "Tokens.swift")
        let properties = declaredNames(of: "Prop", in: tokenSource)
        let events = declaredNames(of: "Event", in: tokenSource)

        XCTAssertTrue(
            properties.isDisjoint(with: [
                "snapInterval", "snapFrom", "snapsAtMost", "scrollMomentum", "scrollStep",
            ]),
            "a scroller's grid, momentum or report step is back in the host contract")
        XCTAssertFalse(events.contains("snapItemChanged"), "a scroller reports a grid item again")
    }

    /// No host provides a swipe view with its actions, or a refresh view, as
    /// an element of its own: they were withdrawn by decision and do not
    /// return. Swipe actions come back with the collection's contract, and a
    /// refresh with the scroller and the collection.
    func testNoSwipeViewAndNoRefreshViewStandsAlone() {
        for name in ["SwipeView", "SwipeActions", "SwipeAction", "RefreshView"] {
            XCTAssertNil(Self.layer(of: NodeType(name)), "\(name) has a contract again")
        }
        for name in ["swipeStarted", "swipeChanging", "swipeEnded", "refreshRequested", "isRefreshingChanged"] {
            XCTAssertNil(Self.facts(of: name, kind: .event), "a withdrawn element's \(name) is back")
        }
        for name in ["isRefreshing", "isRefreshEnabled", "swipeBehaviorOnInvoked"] {
            XCTAssertNil(Self.facts(of: name, kind: .property), "a withdrawn element's \(name) is back")
        }
    }

    /// Every view speaks in plain words: the size it asks for is its width and
    /// height, how it sits in its space is its alignment, and what it does with
    /// input, direction, clipping, its pivot and its context menu is said the
    /// way a reader says it; its background is one property, a colour or a
    /// gradient. The spellings they replaced do not return, and neither do the
    /// size read-backs - a frame report says where a view is.
    func testEveryViewSpeaksInPlainWords() throws {
        let tokenSource = try SourceTree.text(in: "Tokens.swift")
        let controls = declaredNames(of: "NodeType", in: tokenSource)
        let properties = declaredNames(of: "Prop", in: tokenSource)
        let events = declaredNames(of: "Event", in: tokenSource)
        let former = [
            "widthRequest", "heightRequest", "minimumWidthRequest", "minimumHeightRequest",
            "maximumWidthRequest", "maximumHeightRequest", "horizontalOptions",
            "verticalOptions", "inputTransparent", "cascadeInputTransparent",
            "flowDirection", "isClippedToBounds", "anchorX", "anchorY", "backgroundColor",
        ]

        XCTAssertTrue(properties.isSuperset(of: [
            "width", "height", "minimumWidth", "minimumHeight", "maximumWidth",
            "maximumHeight", "horizontalAlignment", "verticalAlignment", "ignoresInput",
            "letsInputThrough", "layoutDirection", "clipsContent", "pivotX", "pivotY",
        ]))
        XCTAssertTrue(
            properties.isDisjoint(with: former),
            "a former view property remains in the host contract")
        XCTAssertTrue(
            events.isDisjoint(with: ["widthChanged", "heightChanged"]),
            "a size read-back remains beside the frame report")
        XCTAssertTrue(controls.contains("ContextMenu"))
        XCTAssertFalse(controls.contains("ContextFlyout"), "the context menu keeps its former name")

        let files = try SourceTree.allSources().map(\.path)
            .filter { $0.hasPrefix("Views/") || $0.hasPrefix("Types/") }
        XCTAssertTrue(files.contains { $0.hasSuffix("/Label.swift") }, "the views are read")
        for file in files {
            let source = try SourceTree.text(in: file)
            for name in former + ["contextFlyout"] {
                XCTAssertFalse(source.contains("func \(name)("), "\(file) still declares .\(name)")
            }
            for type in ["LayoutOptions", "FlowDirection"] {
                XCTAssertFalse(source.contains("enum \(type)"), "\(file) still declares \(type)")
            }
            XCTAssertFalse(
                source.contains("public var backgroundColor"),
                "\(file) still keeps a second background beside `background`")
        }
    }

    /// Text and input speak in plain words: a field is a `TextField`, a
    /// `TextEditor` or a `SearchField`, what its return key does is
    /// `onSubmitted`, and no former spelling is declared anywhere in the
    /// library.
    func testTextAndInputSpeakInPlainWords() throws {
        let tokenSource = try SourceTree.text(in: "Tokens.swift")
        let controls = declaredNames(of: "NodeType", in: tokenSource)
        let properties = declaredNames(of: "Prop", in: tokenSource)
        let events = declaredNames(of: "Event", in: tokenSource)
        let former = [
            "formattedText", "maxLines", "maxLength", "lineBreakMode", "textTransform",
            "keyboard", "returnType", "clearButtonVisibility", "autoSize",
        ]

        XCTAssertTrue(controls.isSuperset(of: ["TextField", "TextEditor", "SearchField", "Spans"]))
        XCTAssertTrue(
            controls.isDisjoint(with: ["Entry", "Editor", "SearchBar", "FormattedString"]),
            "a text control keeps its former name")
        XCTAssertTrue(properties.isSuperset(of: [
            "maximumLines", "maximumLength", "lineBreak", "textCase", "inputPurpose",
            "returnKey", "showsClearButton", "growsWithText",
        ]))
        XCTAssertTrue(
            properties.isDisjoint(with: former),
            "a former text property remains in the host contract")
        XCTAssertTrue(events.contains("submitted"))
        XCTAssertTrue(
            events.isDisjoint(with: ["completed", "searchButtonPressed"]),
            "a field's return key keeps a former event")

        let files = try FileManager.default
            .subpathsOfDirectory(atPath: SourceTree.sources.path)
            .filter { $0.hasSuffix(".swift") }
        XCTAssertGreaterThan(files.count, 50)
        for file in files {
            let source = try SourceTree.text(in: file)
            for name in former + ["onCompleted", "onSearchButtonPressed"] {
                XCTAssertFalse(source.contains("func \(name)("), "\(file) still declares .\(name)")
            }
            for type in [
                "LineBreakMode", "TextTransform", "Keyboard", "ReturnType",
                "ClearButtonVisibility", "EditorAutoSizeOption",
            ] {
                XCTAssertFalse(
                    source.contains("enum \(type):") || source.contains("enum \(type) {"),
                    "\(file) still declares \(type)")
            }
            for control in ["Entry", "Editor", "SearchBar"] {
                XCTAssertFalse(source.contains("struct \(control):"), "\(file) still declares \(control)")
            }
        }
    }

    /// Every control speaks in plain words: a box of colour is a `ColorBox`, a
    /// drawing surface a `Canvas`, the dots beside a carousel a
    /// `PositionIndicator`, and a menu is a `Menu` at any depth - on the bar or
    /// inside another - holding `MenuItem`s and `MenuSeparator`s.
    func testControlsSpeakInPlainWords() throws {
        let tokenSource = try SourceTree.text(in: "Tokens.swift")
        let controls = declaredNames(of: "NodeType", in: tokenSource)
        let events = declaredNames(of: "Event", in: tokenSource)
        let former = [
            "BoxView", "GraphicsView", "IndicatorView", "SwipeItem", "SwipeItems",
            "MenuBarItem", "MenuBarItems", "MenuFlyoutItem", "MenuFlyoutSubItem",
            "MenuFlyoutSeparator",
        ]

        XCTAssertTrue(controls.isSuperset(of: [
            "ColorBox", "Canvas", "PositionIndicator",
            "Menu", "MenuBar", "MenuItem", "MenuSeparator",
        ]))
        XCTAssertTrue(controls.isDisjoint(with: former), "a control keeps its former name")
        XCTAssertTrue(events.contains("dragged"))
        XCTAssertTrue(
            events.isDisjoint(with: [
                "startInteraction", "dragInteraction", "endInteraction", "invoked",
            ]),
            "a canvas or an item keeps a former event")

        let files = try FileManager.default
            .subpathsOfDirectory(atPath: SourceTree.sources.path)
            .filter { $0.hasSuffix(".swift") }
        for file in files {
            let source = try SourceTree.text(in: file)
            for control in former {
                XCTAssertFalse(source.contains("struct \(control):"), "\(file) still declares \(control)")
            }
            for name in ["onStartInteraction", "onDragInteraction", "onEndInteraction", "onInvoked"] {
                XCTAssertFalse(source.contains("func \(name)("), "\(file) still declares .\(name)")
            }
            XCTAssertFalse(source.contains("var menuBarItems"), "\(file) still keeps menuBarItems")
        }
    }

    /// A control's properties speak in plain words: a stepper moves by its
    /// `step`, a picker offers `options`, a grid has `rows` and `columns` of
    /// `.fixed`, `.proportional` or `.fill` length, a Boolean choice is `isOn`
    /// and reports `onToggled`, a toolbar item has a `placement`.
    func testControlPropertiesSpeakInPlainWords() throws {
        let tokenSource = try SourceTree.text(in: "Tokens.swift")
        let properties = declaredNames(of: "Prop", in: tokenSource)
        let events = declaredNames(of: "Event", in: tokenSource)
        let former = [
            "increment", "itemsSource", "isAnimationPlaying", "rowDefinitions",
            "columnDefinitions", "absoluteLayoutFlags", "isShowingUser", "order",
            "isToggled", "isChecked", "absoluteLayoutBounds", "absoluteLayoutProportions",
        ]

        XCTAssertTrue(properties.isSuperset(of: [
            "step", "options", "isAnimating", "rows", "columns",
            "area", "showsUserLocation", "placement", "isOn",
        ]))
        XCTAssertTrue(
            properties.isDisjoint(with: former),
            "a former control property remains in the host contract")
        XCTAssertTrue(events.contains("toggled"))
        XCTAssertFalse(events.contains("checkedChanged"), "a Boolean choice keeps a second event")

        let files = try FileManager.default
            .subpathsOfDirectory(atPath: SourceTree.sources.path)
            .filter { $0.hasSuffix(".swift") }
        for file in files {
            let source = try SourceTree.text(in: file)
            for name in former + ["galleryStyle", "onCheckedChanged", "scroll"] {
                XCTAssertFalse(
                    source.contains("public func \(name)("), "\(file) still declares .\(name)")
            }
            for type in ["enum GalleryStyle", "enum ToolbarItemOrder", "struct AbsoluteLayoutFlags"] {
                XCTAssertFalse(source.contains(type), "\(file) still declares \(type)")
            }
        }

        let lengths = try SourceTree.text(in: "GridLength.swift")
        XCTAssertFalse(
            lengths.contains("case star(") || lengths.contains("case absolute("),
            "a grid length is named in markup words")
    }

    /// An image and a shape fill their room in one vocabulary: `.aspect(.fit)`,
    /// `.fill`, `.stretch` or `.center` - no second enum for shapes and no case
    /// that repeats its type.
    func testAspectIsOneWordForImagesAndShapes() throws {
        let aspectSource = try SourceTree.text(in: "Aspect.swift")
        for aspect in ["case fit = 0", "case fill = 1", "case stretch = 2", "case center = 3"] {
            XCTAssertTrue(aspectSource.contains(aspect), "Aspect does not declare `\(aspect)`")
        }

        let files = try FileManager.default
            .subpathsOfDirectory(atPath: SourceTree.sources.path)
            .filter { $0.hasSuffix(".swift") }
        for file in files {
            let source = try SourceTree.text(in: file)
            for former in ["enum Stretch", "Binding<Stretch>", "aspectFit", "aspectFill", "uniformToFill"] {
                XCTAssertFalse(source.contains(former), "\(file) still says \(former)")
            }
        }
    }

    /// A button with an icon is a `Button`: one `icon` for the picture beside
    /// a caption - on a button, a menu or toolbar item, a page's tab - with its
    /// `iconPosition` and `iconSpacing`, and `Button(icon:)` when there is no
    /// caption at all.
    func testAControlHasOneAccentColour() throws {
        let tokenSource = try SourceTree.text(in: "Tokens.swift")
        let properties = declaredNames(of: "Prop", in: tokenSource)

        XCTAssertTrue(properties.contains("tint"))
        XCTAssertTrue(properties.contains("color"), "a ColorBox keeps its colour")
        XCTAssertTrue(
            properties.isDisjoint(with: [
                "onColor", "offColor", "thumbColor", "thumbImageSource", "minimumTrackColor",
                "maximumTrackColor", "progressColor", "refreshColor", "titleColor",
                "cancelButtonColor", "searchIconColor",
            ]),
            "a control keeps a colour of its own beside its accent")

        for (file, control) in [
            ("Switch.swift", "Switch"), ("Slider.swift", "Slider"),
            ("ProgressBar.swift", "ProgressBar"),
            ("ActivityIndicator.swift", "ActivityIndicator"),
            ("CheckBox.swift", "CheckBox"), ("Picker.swift", "Picker"),
            ("SearchField.swift", "SearchField"),
        ] {
            let source = try SourceTree.text(in: file)
            XCTAssertTrue(source.contains("TintElement"), "\(control) takes no tint")
            XCTAssertFalse(source.contains("public func color("), "\(control) keeps a colour beside its tint")
        }
    }

    func testAccessibilityWordsShareOneFamily() throws {
        let tokenSource = try SourceTree.text(in: "Tokens.swift")
        let properties = declaredNames(of: "Prop", in: tokenSource)

        XCTAssertTrue(properties.isSuperset(of: [
            "accessibilityIdentifier", "accessibilityLabel", "accessibilityHint",
            "accessibilityHeadingLevel", "isAccessibilityHidden",
        ]))
        XCTAssertTrue(
            properties.isDisjoint(with: [
                "automationId", "semanticDescription", "semanticHint", "semanticHeadingLevel",
                "automationIsInAccessibleTree",
            ]),
            "one accessibility concept keeps two prefixes")

        let files = try FileManager.default
            .subpathsOfDirectory(atPath: SourceTree.sources.path)
            .filter { $0.hasSuffix(".swift") }
        var everything = ""
        for file in files {
            let source = try SourceTree.text(in: file)
            everything += source
            for former in [
                "func automationId(", "func semanticDescription(", "func semanticHint(",
                "func semanticHeadingLevel(", "func automationIsInAccessibleTree(",
                "enum SemanticHeadingLevel",
            ] {
                XCTAssertFalse(source.contains(former), "\(file) still says \(former)")
            }
        }
        XCTAssertTrue(everything.contains("public enum HeadingLevel"))
        XCTAssertTrue(everything.contains("public func isAccessibilityHidden(_ value: Bool)"))
    }

    func testTypesSpeakInPlainWords() throws {
        let tokenSource = try SourceTree.text(in: "Tokens.swift")
        let properties = declaredNames(of: "Prop", in: tokenSource)
        let acts = declaredNames(of: "Act", in: tokenSource)

        XCTAssertTrue(properties.contains("avoidsSafeArea"))
        XCTAssertFalse(properties.contains("safeAreaEdges"), "a layout's safe area keeps a second name")
        XCTAssertTrue(acts.contains("hideOnScreenKeyboard"))
        XCTAssertFalse(acts.contains("hideSoftInput"), "the keyboard keeps a second name")

        let files = try FileManager.default
            .subpathsOfDirectory(atPath: SourceTree.sources.path)
            .filter { $0.hasSuffix(".swift") }
        var everything = ""
        for file in files {
            let source = try SourceTree.text(in: file)
            everything += source
            for former in [
                "struct Thickness:", "enum DeviceIdiom", "enum AppTheme", "case unspecified",
                "enum GestureStatus", "case sinIn", "case sinOut",
                "enum SemanticScreenReader", "enum SoftInput", "enum SafeAreaRegions", "case softInput",
                "func safeAreaEdges(", "protocol BindableObject", "var idiom", "let idiom:",
                "var status: GesturePhase",
            ] {
                XCTAssertFalse(source.contains(former), "\(file) still says \(former)")
            }
        }
        for spelling in [
            "public struct Insets:", "public enum FormFactor", "public enum Theme", "case system",
            "public enum GesturePhase", "case sineIn", "case sineOut", "public enum ScreenReader",
            "public enum OnScreenKeyboard", "public enum SafeArea", "case keyboard",
            "func avoidsSafeArea(", "public protocol ModifiableElement", "var formFactor",
            "var phase: GesturePhase",
        ] {
            XCTAssertTrue(everything.contains(spelling), "no source says \(spelling)")
        }
    }

    func testQuestionsAndActsSayWhatTheyAsk() throws {
        let tokenSource = try SourceTree.text(in: "Tokens.swift")
        let acts = declaredNames(of: "Act", in: tokenSource)

        XCTAssertTrue(acts.isSuperset(of: [
            "alert", "confirm", "chooseAction", "prompt",
            "currentTime", "currentTimeZone", "utcOffset", "evaluateJavaScript",
        ]))
        XCTAssertTrue(
            acts.isDisjoint(with: [
                "displayAlertAsync", "displayActionSheetAsync", "displayPromptAsync",
                "dateTimeNow", "localTimeZone", "getUtcOffset", "evaluateJavaScriptAsync",
            ]),
            "an act keeps a name the Swift side does not say")

        let dialogs = try SourceTree.text(in: "Dialogs.swift")
        for spelling in ["func alert(", "func confirm(", "func chooseAction(", "func prompt("] {
            XCTAssertTrue(dialogs.contains(spelling), "Dialogs does not say \(spelling)")
        }

        let files = try FileManager.default
            .subpathsOfDirectory(atPath: SourceTree.sources.path)
            .filter { $0.hasSuffix(".swift") }
        for file in files {
            let source = try SourceTree.text(in: file)
            for former in [
                "func displayAlert(", "func displayActionSheet(", "func displayPrompt(",
                "func getUtcOffset(",
            ] {
                XCTAssertFalse(source.contains(former), "\(file) still says \(former)")
            }
        }
    }

    func testABarNamesItsForegroundOnce() throws {
        let tokenSource = try SourceTree.text(in: "Tokens.swift")
        let properties = declaredNames(of: "Prop", in: tokenSource)

        XCTAssertTrue(properties.isSuperset(of: ["barForegroundColor", "hidesWhenInactive"]))
        XCTAssertTrue(
            properties.isDisjoint(with: ["barTextColor", "foregroundColor", "autoHide"]),
            "a bar's foreground, or when a window hides, keeps a second name")

        for (file, spelling) in [
            ("NavigationStack.swift", "func barForegroundColor("),
            ("TitleBar.swift", "func barForegroundColor("),
            ("WindowGroup.swift", "func hidesWhenInactive("),
        ] {
            let source = try SourceTree.text(in: file)
            XCTAssertTrue(source.contains(spelling), "\(file) does not say \(spelling)")
        }

        let files = try FileManager.default
            .subpathsOfDirectory(atPath: SourceTree.sources.path)
            .filter { $0.hasSuffix(".swift") }
        for file in files {
            let source = try SourceTree.text(in: file)
            for former in ["func barTextColor(", "func foregroundColor(", "func autoHide("] {
                XCTAssertFalse(source.contains(former), "\(file) still says \(former)")
            }
        }
    }

    func testEventsNameWhatHappened() throws {
        let tokenSource = try SourceTree.text(in: "Tokens.swift")
        let events = declaredNames(of: "Event", in: tokenSource)
        let properties = declaredNames(of: "Prop", in: tokenSource)

        XCTAssertTrue(events.isSuperset(of: [
            "dateChanged", "timeChanged", "pinClicked", "pinDetailsClicked",
        ]))
        XCTAssertTrue(
            events.isDisjoint(with: [
                "dateSelected", "timeSelected", "refreshing", "markerClicked", "infoWindowClicked",
            ]),
            "an event keeps a name that says how it happened rather than what happened")
        XCTAssertTrue(properties.contains("tapCount"))
        XCTAssertFalse(properties.contains("numberOfTapsRequired"), "a double tap keeps a second name")

        let files = try FileManager.default
            .subpathsOfDirectory(atPath: SourceTree.sources.path)
            .filter { $0.hasSuffix(".swift") }
        for file in files {
            let source = try SourceTree.text(in: file)
            for former in [
                "func onDateSelected(", "func onTimeSelected(", "func onRefreshing(",
                "func onMarkerClicked(", "func onInfoWindowClicked(", "numberOfTapsRequired:",
            ] {
                XCTAssertFalse(source.contains(former), "\(file) still says \(former)")
            }
        }
    }

    func testARoundedRectangleIsARectangle() throws {
        let tokenSource = try SourceTree.text(in: "Tokens.swift")
        let controls = declaredNames(of: "NodeType", in: tokenSource)
        let properties = declaredNames(of: "Prop", in: tokenSource)

        XCTAssertFalse(controls.contains("RoundRectangle"), "a rounded rectangle is a second rectangle")
        XCTAssertTrue(
            properties.isDisjoint(with: ["radiusX", "radiusY"]),
            "a rectangle's corners keep a second name")

        let rectangle = try SourceTree.text(in: "Rectangle.swift")
        XCTAssertTrue(rectangle.contains("public func cornerRadius(_ value: Double) -> Modified"))

        let files = try FileManager.default
            .subpathsOfDirectory(atPath: SourceTree.sources.path)
            .filter { $0.hasSuffix(".swift") }
        for file in files {
            let source = try SourceTree.text(in: file)
            for former in [
                "struct RoundRectangle:", "protocol RoundRectangleProperties",
                "func radiusX(", "func radiusY(",
            ] {
                XCTAssertFalse(source.contains(former), "\(file) still says \(former)")
            }
        }
    }

    func testOutlinesShapesAndDrawingSpeakInPlainWords() throws {
        let tokenSource = try SourceTree.text(in: "Tokens.swift")
        let properties = declaredNames(of: "Prop", in: tokenSource)

        XCTAssertTrue(properties.isSuperset(of: ["strokeWidth", "shape", "strokeDashPattern"]))
        XCTAssertTrue(
            properties.isDisjoint(with: ["strokeThickness", "strokeShape", "strokeDashArray"]),
            "a line's width, a layout's shape or a dash pattern keeps a second name")

        let color = try SourceTree.text(in: "Color.swift")
        XCTAssertTrue(
            color.contains("public init(red: Int, green: Int, blue: Int, alpha: Int = 255)"),
            "a colour from its channels is Color(red:green:blue:alpha:)")

        let files = try FileManager.default
            .subpathsOfDirectory(atPath: SourceTree.sources.path)
            .filter { $0.hasSuffix(".swift") }
        for file in files {
            let source = try SourceTree.text(in: file)
            for former in [
                "func strokeThickness(", "func strokeShape(", "func strokeDashArray(",
                "enum StrokeShape", "case roundRectangle(", "enum PenLineCap", "enum PenLineJoin",
                "func fontColor(", "func strokeSize(", "func drawString(",
                "enum HorizontalAlignment", "enum VerticalAlignment",
                "func fromArgb(", "func fromRgb(", "func fromRgba(",
            ] {
                XCTAssertFalse(source.contains(former), "\(file) still says \(former)")
            }
        }
    }

    func testAButtonWithAnIconIsAButton() throws {
        let tokenSource = try SourceTree.text(in: "Tokens.swift")
        let controls = declaredNames(of: "NodeType", in: tokenSource)
        let properties = declaredNames(of: "Prop", in: tokenSource)

        XCTAssertFalse(controls.contains("ImageButton"), "an image button is a second button")
        XCTAssertTrue(properties.isSuperset(of: ["icon", "iconPosition", "iconSpacing"]))
        XCTAssertTrue(
            properties.isDisjoint(with: ["imageSource", "iconImageSource", "contentLayout"]),
            "a picture beside a caption keeps a second name")

        let button = try SourceTree.text(in: "Button.swift")
        XCTAssertTrue(button.contains("public init(icon: ImageSource)"))

        let files = try FileManager.default
            .subpathsOfDirectory(atPath: SourceTree.sources.path)
            .filter { $0.hasSuffix(".swift") }
        for file in files {
            let source = try SourceTree.text(in: file)
            for former in [
                "struct ImageButton:", "func imageSource(", "func iconImageSource(",
                "func contentLayout(", "enum ButtonContentPosition", "var iconImageSource",
            ] {
                XCTAssertFalse(source.contains(former), "\(file) still says \(former)")
            }
        }
    }

    /// The names the library's contracts declare members of one kind under.
    private static func names(of kind: MemberFacts.Kind) -> Set<String> {
        Set(LibraryContracts.all.flatMap { contract in
            contract.members.compactMap { member in
                (member as? any DeclaredMember)?.facts.kind == kind ? member.name : nil
            }
        })
    }

    /// The layer an element's contract declares, by its node type - nil for a
    /// type no library contract declares.
    private static func layer(of type: NodeType) -> ElementLayer? {
        LibraryContracts.elements.first { $0.nodeType == type }?.layer
    }

    /// The layer the properties of one name declare - the members of one name
    /// share it (`LibraryContractTests`).
    private static func layer(of property: Prop) -> ElementLayer? {
        facts(of: property.name, kind: .property)?.layer
    }

    /// The layer the events of one name declare.
    private static func layer(of event: Event) -> ElementLayer? {
        facts(of: event.name, kind: .event)?.layer
    }

    /// What the first member of a name and a kind says of itself.
    private static func facts(of name: String, kind: MemberFacts.Kind) -> MemberFacts? {
        for contract in LibraryContracts.all {
            for member in contract.members where member.name == name {
                if let facts = (member as? any DeclaredMember)?.facts, facts.kind == kind {
                    return facts
                }
            }
        }

        return nil
    }

    /// Every source under Types/, where the closed vocabularies and the sessions stand.
    private static func typeSources() throws -> [(path: String, text: String)] {
        try SourceTree.allSources().filter { $0.path.hasPrefix("Types/") }
    }

    private func declaredNames(of vocabulary: String, in source: String) -> Set<String> {
        SourceTree.tokenNames(of: vocabulary, in: source)
    }

    private func assertCoverage(
        classified: Set<String>,
        declared: Set<String>,
        vocabulary: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            classified,
            declared,
            """
            \(vocabulary) ownership is incomplete.
            Unclassified: \(declared.subtracting(classified).sorted())
            Undeclared: \(classified.subtracting(declared).sorted())
            """,
            file: file,
            line: line)
    }

    private func assertDocumented(
        _ names: some Sequence<String>,
        vocabulary: String,
        in document: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let missing = names.filter { !document.contains("`\($0)`") }.sorted()
        XCTAssertTrue(
            missing.isEmpty,
            "platform contract is missing \(vocabulary) tokens: \(missing)",
            file: file,
            line: line)
    }
}
