// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

/// The native-host contract is closed over StateUI's built-in vocabulary even
/// though applications remain free to add their own tokens.
final class HostContractTests: XCTestCase {
    func testEveryBuiltInControlPropertyAndEventHasOneOwner() throws {
        let source = try String(
            contentsOf: Fixtures.sources.appendingPathComponent("Core/Tokens.swift"),
            encoding: .utf8)

        assertCoverage(
            classified: Set(HostContract.controls.keys.map(\.name)),
            declared: declaredNames(of: "NodeType", in: source),
            vocabulary: "NodeType")
        assertCoverage(
            classified: Set(HostContract.properties.keys.map(\.name)),
            declared: declaredNames(of: "Prop", in: source),
            vocabulary: "Prop")
        assertCoverage(
            classified: Set(HostContract.events.keys.map(\.name)),
            declared: declaredNames(of: "Event", in: source),
            vocabulary: "Event")
    }

    /// Page presentation, safe-area layout, backdrop composition, focus
    /// dismissal and navigation-title composition are expressed by their
    /// dedicated StateUI structures. They do not create a second, page-only
    /// vocabulary for capabilities that native hosts do not share.
    func testPageVocabularyContainsOnlySharedCapabilities() throws {
        let source = try String(
            contentsOf: Fixtures.sources.appendingPathComponent("Core/Tokens.swift"),
            encoding: .utf8)
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
        let tokenSource = try String(
            contentsOf: Fixtures.sources.appendingPathComponent("Core/Tokens.swift"),
            encoding: .utf8)
        let barSource = try String(
            contentsOf: Fixtures.sources.appendingPathComponent("Views/BarElement.swift"),
            encoding: .utf8)
        let navigationSource = try String(
            contentsOf: Fixtures.sources.appendingPathComponent("Views/NavigationStack.swift"),
            encoding: .utf8)
        let tabSource = try String(
            contentsOf: Fixtures.sources.appendingPathComponent("Views/TabbedView.swift"),
            encoding: .utf8)
        let properties = declaredNames(of: "Prop", in: tokenSource)

        XCTAssertFalse(properties.contains("barBackground"))
        XCTAssertFalse(properties.contains("selectedTabColor"))
        XCTAssertFalse(properties.contains("unselectedTabColor"))
        XCTAssertFalse(barSource.contains("func barBackground("))
        XCTAssertFalse(barSource.contains("func barTextColor("))
        XCTAssertTrue(navigationSource.contains("func barTextColor("))
        XCTAssertFalse(tabSource.contains("func selectedTabColor("))
        XCTAssertFalse(tabSource.contains("func unselectedTabColor("))
    }

    /// The reader owns whether a flyout is open; the native host owns how its
    /// panes adapt and which native gestures are available on that platform.
    func testFlyoutVocabularyDoesNotExposeHostPresentationPolicy() throws {
        let tokenSource = try String(
            contentsOf: Fixtures.sources.appendingPathComponent("Core/Tokens.swift"),
            encoding: .utf8)
        let enumSource = try String(
            contentsOf: Fixtures.sources.appendingPathComponent("Types/Enums.swift"),
            encoding: .utf8)
        let flyoutSource = try String(
            contentsOf: Fixtures.sources.appendingPathComponent("Views/SplitView.swift"),
            encoding: .utf8)
        let properties = declaredNames(of: "Prop", in: tokenSource)

        XCTAssertFalse(properties.contains("flyoutLayoutBehavior"))
        XCTAssertFalse(properties.contains("isGestureEnabled"))
        XCTAssertFalse(enumSource.contains("enum FlyoutLayoutBehavior"))
        XCTAssertFalse(flyoutSource.contains("func flyoutLayoutBehavior("))
        XCTAssertFalse(flyoutSource.contains("func isGestureEnabled("))
    }

    /// Stack names stay identical from application source through the typed
    /// host boundary. There is no second layout-shaped spelling to translate
    /// or preserve.
    func testStackVocabularyUsesThePublicStateUISpellings() throws {
        let tokenSource = try String(
            contentsOf: Fixtures.sources.appendingPathComponent("Core/Tokens.swift"),
            encoding: .utf8)
        let stackSource = try String(
            contentsOf: Fixtures.sources.appendingPathComponent("Views/StackLayouts.swift"),
            encoding: .utf8)
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
        let tokenSource = try String(
            contentsOf: Fixtures.sources.appendingPathComponent("Core/Tokens.swift"),
            encoding: .utf8)
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

        for (path, text) in try Fixtures.allSources() {
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
        let tokenSource = try String(
            contentsOf: Fixtures.sources.appendingPathComponent("Core/Tokens.swift"),
            encoding: .utf8)
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

        for (path, text) in try Fixtures.allSources() {
            XCTAssertNil(
                text.range(of: "\\bprotocol ContentPage\\b", options: .regularExpression),
                "ContentPage is declared again in \(path)")
        }
    }

    func testDerivedLayoutsAndControlsBelongToStateUI() {
        for type in [
            NodeType.checkBox, .ellipse, .grid, .imageButton,
            .positionIndicator, .line, .path, .polygon, .polyline, .radioButton,
            .rectangle, .refreshView, .roundRectangle, .swipeView,
        ] {
            XCTAssertEqual(HostContract.controls[type], .stateUI)
        }

        for property in [
            Prop.columns, .gridColumn, .gridColumnSpan, .gridRow,
            .gridRowSpan, .rows,
        ] {
            XCTAssertEqual(HostContract.properties[property], .stateUI)
        }
    }

    func testProtocolNodesRemainStructural() {
        for type in [
            NodeType.application, .scene, .window, .overlay, .swipeAction,
        ] {
            XCTAssertEqual(HostContract.controls[type], .structure)
        }
    }

    func testProviderSurfaceDoesNotBecomeABaseHostRequirement() {
        XCTAssertEqual(HostContract.controls[.map], .provider)
        XCTAssertEqual(HostContract.controls[.pin], .provider)
        XCTAssertEqual(HostContract.properties[.mapType], .provider)
        XCTAssertEqual(HostContract.properties[.region], .provider)
        XCTAssertEqual(HostContract.events[.mapClicked], .provider)
    }

    func testPlatformContractNamesEveryBuiltInTokenAndTargetHost() throws {
        let document = try String(
            contentsOf: Fixtures.repository.appendingPathComponent("docs/platform-contract.md"),
            encoding: .utf8)
        let statusRows = document
            .components(separatedBy: "## Complete host vocabulary")[0]
            .split(separator: "\n")
            .filter { $0.hasPrefix("| ") }
            .joined(separator: "\n")

        assertDocumented(
            HostContract.controls.keys.map(\.name),
            vocabulary: "control",
            in: statusRows)
        assertDocumented(
            HostContract.properties.keys.map(\.name),
            vocabulary: "property",
            in: statusRows)
        assertDocumented(
            HostContract.events.keys.map(\.name),
            vocabulary: "event",
            in: statusRows)

        for host in ["AppKit", "UIKit", "GTK 4", "Android Views", "WinUI 3", "Web"] {
            XCTAssertTrue(document.contains(host), "platform contract does not name \(host)")
        }
        XCTAssertTrue(document.contains("✅ means"), "platform contract does not define completion")
    }

    /// Every view speaks in plain words: the size it asks for is its width and
    /// height, how it sits in its space is its alignment, and what it does with
    /// input, direction, clipping, its pivot and its context menu is said the
    /// way a reader says it; its background is one property, a colour or a
    /// gradient. The spellings they replaced do not return, and neither do the
    /// size read-backs - a frame report says where a view is.
    func testEveryViewSpeaksInPlainWords() throws {
        let tokenSource = try String(
            contentsOf: Fixtures.sources.appendingPathComponent("Core/Tokens.swift"),
            encoding: .utf8)
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

        for file in [
            "Views/Elements.swift", "Views/Bound.swift", "Views/Label.swift",
            "Views/SwipeView.swift", "Types/Enums.swift", "Types/PageSession.swift",
        ] {
            let source = try String(
                contentsOf: Fixtures.sources.appendingPathComponent(file),
                encoding: .utf8)
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
        let tokenSource = try String(
            contentsOf: Fixtures.sources.appendingPathComponent("Core/Tokens.swift"),
            encoding: .utf8)
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
            .subpathsOfDirectory(atPath: Fixtures.sources.path)
            .filter { $0.hasSuffix(".swift") }
        XCTAssertGreaterThan(files.count, 50)
        for file in files {
            let source = try String(
                contentsOf: Fixtures.sources.appendingPathComponent(file),
                encoding: .utf8)
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
    /// `PositionIndicator`, what a swipe reveals a `SwipeAction`, and a menu is
    /// a `Menu` at any depth - on the bar or inside another - holding
    /// `MenuItem`s and `MenuSeparator`s.
    func testControlsSpeakInPlainWords() throws {
        let tokenSource = try String(
            contentsOf: Fixtures.sources.appendingPathComponent("Core/Tokens.swift"),
            encoding: .utf8)
        let controls = declaredNames(of: "NodeType", in: tokenSource)
        let events = declaredNames(of: "Event", in: tokenSource)
        let former = [
            "BoxView", "GraphicsView", "IndicatorView", "SwipeItem", "SwipeItems",
            "MenuBarItem", "MenuBarItems", "MenuFlyoutItem", "MenuFlyoutSubItem",
            "MenuFlyoutSeparator",
        ]

        XCTAssertTrue(controls.isSuperset(of: [
            "ColorBox", "Canvas", "PositionIndicator", "SwipeAction", "SwipeActions",
            "Menu", "MenuBar", "MenuItem", "MenuSeparator",
        ]))
        XCTAssertTrue(controls.isDisjoint(with: former), "a control keeps its former name")
        XCTAssertTrue(events.contains("dragged"))
        XCTAssertTrue(
            events.isDisjoint(with: [
                "startInteraction", "dragInteraction", "endInteraction", "invoked",
            ]),
            "a canvas or a swipe action keeps a former event")

        let files = try FileManager.default
            .subpathsOfDirectory(atPath: Fixtures.sources.path)
            .filter { $0.hasSuffix(".swift") }
        for file in files {
            let source = try String(
                contentsOf: Fixtures.sources.appendingPathComponent(file),
                encoding: .utf8)
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
        let tokenSource = try String(
            contentsOf: Fixtures.sources.appendingPathComponent("Core/Tokens.swift"),
            encoding: .utf8)
        let properties = declaredNames(of: "Prop", in: tokenSource)
        let events = declaredNames(of: "Event", in: tokenSource)
        let former = [
            "increment", "itemsSource", "isAnimationPlaying", "rowDefinitions",
            "columnDefinitions", "absoluteLayoutFlags", "isShowingUser", "order",
            "isToggled", "isChecked",
        ]

        XCTAssertTrue(properties.isSuperset(of: [
            "step", "options", "isAnimating", "rows", "columns",
            "absoluteLayoutProportions", "showsUserLocation", "placement", "isOn",
        ]))
        XCTAssertTrue(
            properties.isDisjoint(with: former),
            "a former control property remains in the host contract")
        XCTAssertTrue(events.contains("toggled"))
        XCTAssertFalse(events.contains("checkedChanged"), "a Boolean choice keeps a second event")

        let files = try FileManager.default
            .subpathsOfDirectory(atPath: Fixtures.sources.path)
            .filter { $0.hasSuffix(".swift") }
        for file in files {
            let source = try String(
                contentsOf: Fixtures.sources.appendingPathComponent(file),
                encoding: .utf8)
            for name in former + ["galleryStyle", "onCheckedChanged", "scroll"] {
                XCTAssertFalse(
                    source.contains("public func \(name)("), "\(file) still declares .\(name)")
            }
            for type in ["enum GalleryStyle", "enum ToolbarItemOrder", "struct AbsoluteLayoutFlags"] {
                XCTAssertFalse(source.contains(type), "\(file) still declares \(type)")
            }
            XCTAssertFalse(
                source.contains("case star(") || source.contains("case absolute("),
                "\(file) still names a grid length in markup words")
        }
    }

    /// An image and a shape fill their room in one vocabulary: `.aspect(.fit)`,
    /// `.fill`, `.stretch` or `.center` - no second enum for shapes and no case
    /// that repeats its type.
    func testAspectIsOneWordForImagesAndShapes() throws {
        let enums = try String(
            contentsOf: Fixtures.sources.appendingPathComponent("Types/Enums.swift"),
            encoding: .utf8)
        for aspect in ["case fit = 0", "case fill = 1", "case stretch = 2", "case center = 3"] {
            XCTAssertTrue(enums.contains(aspect), "Aspect does not declare `\(aspect)`")
        }

        let files = try FileManager.default
            .subpathsOfDirectory(atPath: Fixtures.sources.path)
            .filter { $0.hasSuffix(".swift") }
        for file in files {
            let source = try String(
                contentsOf: Fixtures.sources.appendingPathComponent(file),
                encoding: .utf8)
            for former in ["enum Stretch", "Binding<Stretch>", "aspectFit", "aspectFill", "uniformToFill"] {
                XCTAssertFalse(source.contains(former), "\(file) still says \(former)")
            }
        }
    }

    private func declaredNames(of vocabulary: String, in source: String) -> Set<String> {
        let marker = "= \(vocabulary)(\""

        return Set(source.split(separator: "\n").compactMap { line in
            let code = line.trimmingCharacters(in: .whitespaces)
            guard code.hasPrefix("static let "),
                  let start = code.range(of: marker)?.upperBound,
                  let end = code[start...].firstIndex(of: "\"")
            else { return nil }
            return String(code[start..<end])
        })
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
