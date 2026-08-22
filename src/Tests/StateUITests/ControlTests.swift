// One control at a time: what each one puts on the wire.
//
// The other tests here are about the MECHANISM - identity, memoization, handler
// ids - and controls appear in them only as material. This file is about the
// CONTRACT of each control: a modifier is written in Swift, a property is
// assigned in C#, and nothing between the two says they agree on the name.
//
// That gap is silent by design. An unknown property is ignored rather than
// reported, so a modifier the renderer has not caught up with does nothing at
// all, looks exactly like one that works, and no test that exercises the
// mechanism will ever notice.
//
// So every control is built here with every modifier it declares, and the
// message is kept in `src/Tests/fixtures/controls/`. The C# tests apply those
// files and check the real MAUI properties. Four tests keep the set honest:
//
//   testEveryControlIsWrittenDown   the message still matches its fixture
//   testEveryModifierIsExercised    a modifier missing from a case fails HERE
//   testEveryControlHasACase        a new control with no case fails HERE
//   testTheSharedTierIsCoveredOnce  the protocol tiers, on one tree
//
// The tier modifiers - padding, margin, fontSize, horizontalOptions - are
// deliberately NOT repeated per control. They live on protocols and are applied
// by one method on the C# side, so covering them once per control would prove one
// line two dozen times. That is what the protocol tiers are for; the `Elements`
// case covers them once, on a stack holding a label.

import Foundation
import StateUIWireProbe
import XCTest
@testable import StateUI

/// One control, built with everything of its own that it can do.
private struct ControlCase {
    /// The MAUI type, which is also what the fixture is called.
    let name: String

    /// The file under Views/ whose modifiers this case has to exercise.
    let source: String

    let node: Node

    init(_ name: String, source: String, _ element: any Element) {
        self.name = name
        self.source = source
        self.node = element.body
    }
}

final class ControlTests: XCTestCase {
    /// Built on demand rather than stored: a Node holds the closures its events
    /// run, so the list is not Sendable and cannot be a static `let` under
    /// Swift 6 - the same rule that decided where the library keeps its state.
    private static var cases: [ControlCase] {
        // A binding needs somewhere to live; a State is a reference, so this is
        // the same thing an application holds.
        let scrolled = State(0.0)
        let nearest = State(0)
        let refreshing = State(false)
        let hasBack = State(false)
        let hasForward = State(false)

        return [
            ControlCase("Label", source: "Label.swift",
                Label("Total")
                    .textType(.text)
                    .lineBreakMode(.tailTruncation)
                    .lineHeight(1.5)
                    .maxLines(2)
                    .textDecorations([.underline, .strikethrough])
                    // The runs go here rather than in a case of their own: a
                    // Span is not a view, so it has no fixture, and Label.swift
                    // is the file that declares it.
                    .formattedText {
                        TextSpan("let ")
                            .textColor(.purple)
                            .backgroundColor(.whiteSmoke)
                            .fontSize(13)
                            .fontFamily("Menlo")
                            .fontAttributes(.bold)
                            .fontAutoScalingEnabled(false)
                            .characterSpacing(0.5)
                            .lineHeight(1.2)
                            .textDecorations(.underline)

                        TextSpan("counter").textColor(.steelBlue)
                    }),

            ControlCase("Button", source: "Button.swift",
                Button("Increment")
                    .borderColor(.gray)
                    .borderWidth(1)
                    .cornerRadius(8)
                    .lineBreakMode(.noWrap)
                    .imageSource("tab_list.png")
                    .contentLayout(.left, spacing: 8)
                    .onClicked {}
                    .onPressed {}
                    .onReleased {}),

            ControlCase("Entry", source: "Entry.swift",
                Entry("Ada")
                    .isPassword(false)
                    .returnType(.done)
                    .clearButtonVisibility(.whileEditing)
                    .onTextChanged { _ in }
                    .onCompleted {}),

            ControlCase("Editor", source: "Editor.swift",
                Editor("Notes")
                    .autoSize(.textChanges)
                    .onTextChanged { _ in }
                    .onCompleted {}),

            ControlCase("Image", source: "Image.swift",
                Image("tab_list.png")
                    .aspect(.aspectFill)
                    .isAnimationPlaying(true)
                    .isOpaque(true)),

            ControlCase("ImageButton", source: "ImageButton.swift",
                ImageButton("tab_list.png")
                    .aspect(.aspectFit)
                    .isOpaque(true)
                    .borderColor(.gray)
                    .borderWidth(1)
                    .cornerRadius(8)
                    .onClicked {}
                    .onPressed {}
                    .onReleased {}),

            ControlCase("Picker", source: "Picker.swift",
                Picker(["Small", "Medium", "Large"])
                    .selectedIndex(1)
                    .title("Size")
                    .titleColor(.gray)
                    .isOpen(false)
                    .onSelectedIndexChanged { _ in }
                    .onOpened {}
                    .onClosed {}),

            ControlCase("DatePicker", source: "DatePicker.swift",
                DatePicker(CalendarDate(year: 2026, month: 8, day: 2))
                    .date(CalendarDate(year: 2026, month: 8, day: 9))
                    .minimumDate(CalendarDate(year: 2026, month: 1, day: 1))
                    .maximumDate(CalendarDate(year: 2026, month: 12, day: 31))
                    .format("D")
                    .isOpen(false)
                    .onDateSelected { _ in }
                    .onOpened {}
                    .onClosed {}),

            ControlCase("TimePicker", source: "TimePicker.swift",
                TimePicker(ClockTime(hour: 9, minute: 30))
                    .time(ClockTime(hour: 21, minute: 5, second: 30))
                    .format("t")
                    .isOpen(false)
                    .onTimeSelected { _ in }
                    .onOpened {}
                    .onClosed {}),

            ControlCase("Switch", source: "Switch.swift",
                Switch(true)
                    .isToggled(true)
                    .onColor(.green)
                    .offColor(.lightGray)
                    .thumbColor(.white)
                    .onToggled { _ in }),

            ControlCase("CheckBox", source: "CheckBox.swift",
                CheckBox(true)
                    .isChecked(true)
                    .color(.firebrick)
                    .onCheckedChanged { _ in }),

            ControlCase("RadioButton", source: "RadioButton.swift",
                RadioButton("Medium")
                    .content("Medium")
                    .isChecked(true)
                    .groupName("size")
                    .textTransform(.uppercase)
                    .borderColor(.gray)
                    .borderWidth(1)
                    .cornerRadius(8)
                    .onCheckedChanged { _ in }),

            ControlCase("Slider", source: "Slider.swift",
                Slider(40)
                    .minimum(0)
                    .maximum(100)
                    .minimumTrackColor(.cornflowerBlue)
                    .maximumTrackColor(.lightGray)
                    .thumbColor(.white)
                    .thumbImageSource("thumb.png")
                    .onValueChanged { _ in }
                    .onDragStarted {}
                    .onDragCompleted {}),

            ControlCase("Stepper", source: "Stepper.swift",
                Stepper(4)
                    .value(4)
                    .minimum(1)
                    .maximum(12)
                    .increment(2)
                    .onValueChanged { _ in }),

            ControlCase("SearchBar", source: "SearchBar.swift",
                SearchBar("al")
                    .returnType(.search)
                    .cancelButtonColor(.gray)
                    .searchIconColor(.cornflowerBlue)
                    .onTextChanged { _ in }
                    .onSearchButtonPressed {}),

            ControlCase("ActivityIndicator", source: "ActivityIndicator.swift",
                ActivityIndicator(true)
                    .isRunning(true)
                    .color(.cornflowerBlue)),

            ControlCase("ProgressBar", source: "ProgressBar.swift",
                ProgressBar(0.4)
                    .progress(0.4)
                    .progressColor(.cornflowerBlue)),

            ControlCase("BoxView", source: "BoxView.swift",
                BoxView(.cornflowerBlue)
                    .cornerRadius(8)),

            ControlCase("Border", source: "Border.swift",
                Border {
                    Label("Inside")
                }
                .stroke(.lightGray)
                .strokeThickness(1)
                .strokeShape(.roundRectangle(12))
                // The rest of MAUI's IStroke, which a Border declares of its
                // own beside the identical set on Shape.
                .strokeDashArray([6, 3])
                .strokeDashOffset(2)
                .strokeLineCap(.round)
                .strokeLineJoin(.bevel)
                .strokeMiterLimit(4)),

            ControlCase("IndicatorView", source: "IndicatorView.swift",
                IndicatorView()
                    .count(3)
                    .position(1)
                    .indicatorColor(.lightGray)
                    .selectedIndicatorColor(.cornflowerBlue)
                    .indicatorSize(8)
                    .maximumVisible(5)
                    .indicatorsShape(.square)
                    .hideSingle(false)),

            // The dots as VIEWS - the second shape the same control takes:
            // the items run the template here, and MAUI counts them itself.
            ControlCase("IndicatorDots", source: "IndicatorView.swift",
                IndicatorView(["one", "two", "three"]) { name in
                    Label("*").id(name)
                }
                .position(1)),

            ControlCase("Grid", source: "Grid.swift",
                Grid {
                    Label("Top left")

                    Label("Spanning both")
                        .gridRow(1)
                        .gridColumnSpan(2)
                }
                .rowDefinitions(.absolute(70), .auto)
                .columnDefinitions(.star, .star(2))
                .rowSpacing(12)
                .columnSpacing(8)),

            ControlCase("VerticalStackLayout", source: "StackLayouts.swift",
                VStack {
                    Label("One")
                }
                .spacing(12)),

            ControlCase("HorizontalStackLayout", source: "StackLayouts.swift",
                HStack {
                    Label("One")
                }
                .spacing(6)),

            ControlCase("AbsoluteLayout", source: "AbsoluteLayout.swift",
                AbsoluteLayout {
                    BoxView(.cornflowerBlue)
                        .absoluteLayoutBounds(Rect(0, 0, 1, 0.5))
                        .absoluteLayoutFlags(.all)

                    Label("Bottom right")
                        .absoluteLayoutBounds(
                            Rect(1, 1, AbsoluteLayout.autoSize, AbsoluteLayout.autoSize))
                        .absoluteLayoutFlags(.positionProportional)
                }),

            ControlCase("FlexLayout", source: "FlexLayout.swift",
                FlexLayout {
                    Label("One")

                    Label("Two")
                        .flexLayoutGrow(1)
                        .flexLayoutBasis(.percent(0.5))
                }
                .direction(.column)
                .wrap(.wrap)
                .justifyContent(.spaceBetween)
                .alignItems(.center)
                .alignContent(.spaceEvenly)
                .position(.relative)),

            ControlCase("ScrollView", source: "ScrollView.swift",
                ScrollView {
                    Label("content")
                }
                .orientation(.both)
                .verticalScrollBarVisibility(.never)
                .horizontalScrollBarVisibility(.always)
                .scrollY(scrolled.projectedValue, every: 40)
                .snapInterval(80, from: 10)
                .momentum(0.5)
                .snapItem(nearest.projectedValue)),

            // Both halves of a map: the control, and the pins on it. A Pin is
            // not a control of its own - MAUI's is a BindableObject - so this
            // case is where its modifiers are exercised as well. Where the
            // map LOOKS is an act (moveToRegion), pinned by its command
            // fixture rather than here.
            ControlCase("Map", source: "Map.swift",
                Map(latitude: 52.2297, longitude: 21.0122, radiusMeters: 3000)
                    .mapType(.hybrid)
                    .isScrollEnabled(true)
                    .isZoomEnabled(true)
                    .isTrafficEnabled(false)
                    .isShowingUser(false)
                    .pins {
                        Pin("Royal Castle")
                            .address("Plac Zamkowy 4")
                            .type(.place)
                            .location(latitude: 52.2479, longitude: 21.0155)
                            .onMarkerClicked {}
                            .onInfoWindowClicked {}

                        Pin("Second")
                            .label("Lazienki Park")
                            .location(latitude: 52.2151, longitude: 21.0355)
                    }
                    .onMapClicked { _ in }),

            // The fixture's source is the URL form; HTML written in place
            // travels as a list under the same name, which is the renderer
            // test AWebViewSourceTakesAUrlAndHtmlUnderTheSameName - the brush
            // rule, one level up. The two CanGo bindings are watches, MAUI
            // giving neither property an event.
            ControlCase("WebView", source: "WebView.swift",
                WebView("https://example.com/docs")
                    .userAgent("StateUI/1.0")
                    .canGoBack(hasBack.projectedValue)
                    .canGoForward(hasForward.projectedValue)
                    .onNavigating { _ in }
                    .onNavigated { _ in }
                    .onProcessTerminated {}),

            // The window's own chrome, desktop only. Its three slots are
            // wrapper nodes read by TYPE, the way a page's TitleView is; the
            // C# check also reads the passthrough registration, which is what
            // makes the button in a slot press rather than drag the window.
            ControlCase("TitleBar", source: "TitleBar.swift",
                TitleBar("StateUI Gallery")
                    .subtitle("Fundamentals")
                    .icon("stateui_mark.png")
                    .foregroundColor(.white)
                    .leadingContent {
                        Label("lead")
                    }
                    .content {
                        Label("mid")
                    }
                    .trailingContent {
                        Button("act")
                    }),

            // The binding form, because IsRefreshing is the one property here
            // written from both sides: the pull sets it and the handler clears
            // it, so the fixture has to carry the watch as well as the event.
            ControlCase("RefreshView", source: "RefreshView.swift",
                RefreshView(refreshing.projectedValue) {
                    Label("Pull me")
                }
                .isRefreshing(true)
                .refreshColor(.cornflowerBlue)
                .isRefreshEnabled(true)
                .onRefreshing {}),

            // Both halves of a swipe: the view, and the items each side reveals.
            // SwipeItem is not a control of its own - MAUI's is a MenuItem - so
            // this case is where its modifiers are exercised as well.
            ControlCase("SwipeView", source: "SwipeView.swift",
                SwipeView {
                    Label("Swipe me")
                }
                .threshold(80)
                .onSwipeStarted { _ in }
                .onSwipeChanging { _ in }
                .onSwipeEnded { _ in }
                .leftItems {
                    SwipeItem("Favourite")
                        .iconImageSource("tab_list.png")
                        .backgroundColor(.gold)
                        .isDestructive(false)
                        .isEnabled(true)
                        .isVisible(true)
                        .onInvoked {}
                }
                .rightItems(mode: .execute, swipeBehaviorOnInvoked: .close) {
                    SwipeItem("Remove")
                        .text("Delete")
                        .backgroundColor(.firebrick)
                        .onInvoked {}
                }),

            // The shapes. What they share is the Shape tier, covered once by the
            // Elements case below; each of these carries only its own.
            ControlCase("Rectangle", source: "Rectangle.swift",
                Rectangle()
                    .radiusX(8)
                    .radiusY(4)),

            ControlCase("RoundRectangle", source: "RoundRectangle.swift",
                RoundRectangle()
                    .cornerRadius(topLeft: 16, topRight: 16, bottomLeft: 0, bottomRight: 0)),

            ControlCase("Ellipse", source: "Ellipse.swift", Ellipse()),

            ControlCase("Line", source: "Line.swift",
                Line()
                    .x1(0)
                    .y1(0)
                    .x2(240)
                    .y2(40)),

            ControlCase("Path", source: "Path.swift",
                Path("M 0,40 L 20,0 L 40,40 Z")
                    .data("M 0,40 L 20,0 L 40,40 Z")
                    // A group, so the nesting is exercised too: one transform
                    // holding others is the only shape the reader recurses.
                    .renderTransform(.group([
                        .rotate(15, centerX: 20, centerY: 20),
                        .scale(x: 1.5, y: 0.5, centerX: 1, centerY: 2),
                        .skew(x: 10, y: 5, centerX: 3, centerY: 4),
                        .translate(x: 6, y: 7),
                        .matrix(m11: 1, m12: 0, m21: 0, m22: 1, offsetX: 8, offsetY: 9),
                    ]))),

            ControlCase("Polygon", source: "Polygon.swift",
                Polygon([Point(20, 0), Point(40, 40), Point(0, 40)])
                    .points([Point(20, 0), Point(40, 40), Point(0, 40)])
                    .fillRule(.nonzero)),

            ControlCase("Polyline", source: "Polyline.swift",
                Polyline([Point(0, 30), Point(20, 5), Point(40, 25)])
                    .points([Point(0, 30), Point(20, 5), Point(40, 25)])
                    .fillRule(.evenOdd)),

            // A canvas, and the instructions it draws - every one of them, since
            // the format they travel in is read in one place on the other side.
            ControlCase("GraphicsView", source: "GraphicsView.swift",
                GraphicsView {
                    Draw.fillColor(.cornflowerBlue)
                    Draw.strokeColor(Color(light: .black, dark: .white))
                    Draw.strokeSize(2)
                    Draw.fontColor(.white)
                    Draw.fontSize(14)
                    Draw.alpha(0.9)

                    Draw.drawLine(x1: 0, y1: 0, x2: 40, y2: 40)
                    Draw.drawRectangle(x: 0, y: 0, width: 20, height: 10)
                    Draw.drawRoundedRectangle(x: 0, y: 0, width: 20, height: 10, cornerRadius: 4)
                    Draw.drawEllipse(x: 0, y: 0, width: 20, height: 20)
                    Draw.drawArc(
                        x: 0, y: 0, width: 20, height: 20,
                        startAngle: 0, endAngle: 90, clockwise: true, closed: false)
                    Draw.drawPath("M 0,0 L 10,10 Z")

                    Draw.fillRectangle(x: 0, y: 0, width: 20, height: 10)
                    Draw.fillRoundedRectangle(x: 0, y: 0, width: 20, height: 10, cornerRadius: 4)
                    Draw.fillEllipse(x: 0, y: 0, width: 20, height: 20)
                    Draw.fillArc(
                        x: 0, y: 0, width: 20, height: 20,
                        startAngle: 0, endAngle: 90, clockwise: true)
                    Draw.fillPath("M 0,0 L 10,10 Z")

                    // A comma in the text: the string carries its own length,
                    // so it is text and never a separator.
                    Draw.drawString(
                        "Hello, world", x: 10, y: 20, width: 80, height: 16,
                        horizontalAlignment: .center, verticalAlignment: .bottom)

                    Draw.saveState()
                    Draw.translate(dx: 4, dy: 4)
                    Draw.rotate(45)
                    Draw.scale(sx: 2, sy: 2)
                    Draw.restoreState()
                }
                .onStartInteraction { _ in }
                .onDragInteraction { _ in }
                .onEndInteraction { _ in }),

            // The protocol tiers, once, on the three controls it takes to reach all
            // of them: a stack for spacing and padding, a label for text, font and
            // alignment, and a shape for what a shape is drawn with. The grid
            // placement is on the label because that is where an attached property
            // lives - on the child, not the grid.
            ControlCase("Elements", source: "Elements.swift",
                VStack {
                    // The Shape tier, which MAUI declares once and all seven
                    // shapes inherit - so it is checked here rather than in each
                    // of their cases, exactly as the font tier is.
                    Ellipse()
                        .fill(.radialGradient([
                            GradientStop(.white, 0),
                            GradientStop(.steelBlue, 1),
                        ], center: Point(0.3, 0.3), radius: 0.8))
                        .stroke(.linearGradient([
                            GradientStop(.gold, 0),
                            GradientStop(.tomato, 1),
                        ], startPoint: Point(0, 0), endPoint: Point(1, 1)))
                        .strokeThickness(2)
                        .strokeDashArray([4, 2])
                        .strokeDashOffset(1)
                        .strokeLineCap(.round)
                        .strokeLineJoin(.bevel)
                        .strokeMiterLimit(4)
                        .aspect(.uniformToFill)
                        // A gradient behind a view, which is what a Brush is for
                        // everywhere else.
                        .background(.solidColor(Color(light: .whiteSmoke, dark: .black)))

                    Label("Tiers")
                        .textColor(.firebrick)
                        .characterSpacing(1.5)
                        .textTransform(.uppercase)
                        .fontSize(20)
                        .fontFamily("OpenSansRegular")
                        .fontAttributes(.bold)
                        .fontAutoScalingEnabled(false)
                        .horizontalTextAlignment(.center)
                        .verticalTextAlignment(.end)
                        .gridRow(1)
                        .gridColumn(2)
                        .gridRowSpan(3)
                        .gridColumnSpan(4)
                        // The other two layouts that ask a child where it goes.
                        // Harmless on a view in neither, which is what an
                        // attached property is.
                        .absoluteLayoutBounds(Rect(0, 0, 120, 40))
                        .absoluteLayoutFlags(.sizeProportional)
                        .flexLayoutOrder(2)
                        .flexLayoutGrow(1)
                        .flexLayoutShrink(0)
                        .flexLayoutAlignSelf(.center)
                        .flexLayoutBasis(.percent(0.5))
                        .padding(8, 4)

                    // The InputView tier, which MAUI declares once and Entry,
                    // Editor and SearchBar all inherit - checked here rather
                    // than in each of their cases, exactly as the shape tier
                    // is. The other two controls' renderer reads are pinned by
                    // TheInputTierLandsOnEveryInputView on the C# side.
                    Entry("Ada")
                        .placeholder("Name")
                        .placeholderColor(.lightGray)
                        .isReadOnly(false)
                        .keyboard(.email)
                        .maxLength(40)
                        .isSpellCheckEnabled(false)
                        .isTextPredictionEnabled(false)
                        .cursorPosition(1)
                        .selectionLength(2)
                }
                .spacing(12)
                // The safe strip is the LAYOUT tier's one property of its own;
                // the four-value form pins the full MAUI spelling on the wire.
                .safeAreaEdges(.none, .softInput, .container, .all)
                .isClippedToBounds(true)
                .cascadeInputTransparent(false)
                .style("Card")
                .padding(24, 16, 24, 16)
                .margin(4, 8, 4, 8)
                .horizontalOptions(.center)
                .verticalOptions(.fill)
                .isVisible(true)
                .isEnabled(false)
                .inputTransparent(false)
                .flowDirection(.rightToLeft)
                .opacity(0.5)
                .backgroundColor(.whiteSmoke)
                .widthRequest(200)
                .heightRequest(100)
                .minimumWidthRequest(50)
                .minimumHeightRequest(25)
                .maximumWidthRequest(400)
                .maximumHeightRequest(300)
                .rotation(15)
                .rotationX(30)
                .rotationY(45)
                .scale(1.5)
                .scaleX(2)
                .scaleY(3)
                .translationX(10)
                .translationY(20)
                .anchorX(0.25)
                .anchorY(0.75)
                .zIndex(3)
                // The view's own lifetime, as events - MAUI's Loaded and
                // Unloaded, which a clock starts and stops on.
                .onLoaded {}
                .onUnloaded {}
                // Every gesture MAUI has, on one view - which is legal, and the
                // only way to check that each recognizer is asked for on its
                // own terms.
                .onTapped(numberOfTapsRequired: 2) {}
                .onSwiped(direction: [.left, .up], threshold: 60) { _ in }
                .onPanUpdated(touchCount: 1) { _ in }
                .onPinchUpdated { _ in }
                .onPointerEntered {}
                .onPointerExited {}
                .onPointerMoved { _ in }
                .onPointerPressed { _ in }
                .onPointerReleased { _ in }
                .draggable(text: "Alpha", canDrag: true) {}
                .onDropCompleted {}
                .onDrop { _ in }
                .onDragOver {}
                .onDragLeave {}),
        ]
    }

    // MARK: - The fixtures

    /// Every case, rendered from nothing, written down.
    ///
    /// A fresh differ per case, so each file reads as a first render and the
    /// identities start at 1 - a fixture is easier to read that way, and the C#
    /// side applies each on a renderer of its own anyway.
    func testEveryControlIsWrittenDown() throws {
        for control in Self.cases {
            let differ = Differ()
            let result = differ.reconcile(nil, with: control.node)

            let bytes = Wire.encode(result.patch, generation: 1, dictionary: WireDictionary())
            try Fixtures.check(
                bytes,
                sidecar: WireProbe.dumpMessage(bytes, names: WireNames()),
                against: "controls/\(control.name)")
        }
    }

    // MARK: - The set, kept honest

    /// A modifier that no case uses is a modifier no fixture carries, which is a
    /// modifier the renderer can quietly not implement.
    func testEveryModifierIsExercised() throws {
        var covered: [String: Set<String>] = [:]

        for control in Self.cases {
            covered[control.source, default: []].formUnion(Self.propNames(in: control.node))
        }

        for (source, keys) in covered.sorted(by: { $0.key < $1.key }) {
            let declared = try Fixtures.propertyKeys(in: source)
            let missing = declared.subtracting(keys).sorted()

            XCTAssertTrue(missing.isEmpty, """
                \(source) declares \(missing.joined(separator: ", ")), which no \
                case in this file uses.

                A property no fixture carries is one the renderer can leave out \
                without anything failing. Add the modifier to the case for that \
                control, run with STATEUI_UPDATE_FIXTURES=1, and check the C# \
                side reads it.
                """)
        }
    }

    /// The same promise for a file that has no case OF ITS OWN - a tier.
    ///
    /// The guard above groups by SOURCE FILE and then walks the files that have
    /// cases, so a file with none was never asked about at all. That was
    /// already true of `BarElement.swift`, and it silently became true of three
    /// more the moment the shared tiers were pulled out of the controls that
    /// had been copying them: nine modifiers that Button's, Image's and
    /// SwipeView's cases had been proving stopped being anybody's to prove.
    ///
    /// A tier belongs to several controls, so the question it can answer is
    /// weaker and is the one the other guard's own message asks: is this
    /// property carried by SOME fixture? Proof is taken from wherever it comes,
    /// exactly as `testEveryEventModifierIsExercised` takes it - a sidecar for
    /// anything with a control fixture, and a test for what has none. A
    /// `ToolbarItem` is the case for the second: it is not a view, so it
    /// appears in no `fixtures/controls/` file at all, and PageTests is where
    /// it is built with everything it can do.
    func testEveryModifierOfATierIsExercisedSomewhere() throws {
        let withCases = Set(Self.cases.map(\.source))
        let proof = try (Fixtures.fixtureSidecars()
            + Fixtures.testSources().map(\.text))
            .joined(separator: "\n")
        var missing: [String] = []

        for source in try Fixtures.controlSources() where !withCases.contains(source) {
            for key in try Fixtures.propertyKeys(in: source).sorted()
            // A sidecar writes `  borderColor: color FF808080` and a test writes
            // `.borderColor(`, so both anchors are what keep `text` from being
            // answered by `textColor`.
            where !proof.contains("\(key): ") && !proof.contains(".\(key)(") {
                missing.append("\(source) declares \(key)")
            }
        }

        XCTAssertEqual(missing, [], """
            These are declared by a file with no case of its own, and no \
            fixture carries them:

            \(missing.joined(separator: "\n"))

            A tier is shared, so it has no case of its own - but a property no \
            fixture carries is still one the renderer can leave out without \
            anything failing. Add the modifier to the case of a control that \
            conforms to the tier and run with STATEUI_UPDATE_FIXTURES=1.
            """)
    }

    /// A control with no case at all, which is the same hole one modifier wide.
    /// THE SIBLING OF THE MODIFIER GUARD, for the modifiers it cannot see.
    ///
    /// `testEveryModifierIsExercised` scans for a property being WRITTEN, so a
    /// modifier whose whole body is an `addHandler` is invisible to it: no
    /// property key, nothing to miss. Two of them reached the shelf that way -
    /// `.height($binding)` and `.scrollX($binding)`, each with a C# arm nothing
    /// ever ran.
    ///
    /// Every event a `Views/` file subscribes must therefore be named by some
    /// test, which is a weaker promise than the fixture the properties get -
    /// an event is fired by a test rather than described in a message - but it
    /// is the promise that would have caught these two.
    func testEveryEventModifierIsExercised() throws {
        var subscribed: Set<String> = []

        for file in try Fixtures.controlSources() {
            subscribed.formUnion(try Fixtures.handlerKeys(in: file))
        }

        // ANYWHERE, not just here: an event is proved by whoever proves it -
        // a Swift test firing it, a fixture carrying it, or the C# test that
        // reads the fixture. Demanding a Swift test for each would fail
        // eleven events whose renderer arm is already exercised through a
        // fixture, which is a guard that lies.
        let named = try (Fixtures.testSources().map(\.text)
            + Fixtures.runtimeTestSources().map(\.text)
            + Fixtures.fixtureSidecars())
            .joined(separator: "\n")

        let missing = subscribed
            .filter { !named.contains($0) }
            .sorted()

        XCTAssertEqual(missing, [], """
            These events a control subscribes are named by no test:

            \(missing.joined(separator: ", "))

            An event modifier writes no property, so the modifier guard cannot \
            see it. Fire it in a test - ChangesTests is where the reported \
            properties live - or the renderer's half of it is code nobody runs.
            """)
    }

    func testEveryControlHasACase() throws {
        let covered = Set(Self.cases.map { $0.name })

        for source in try Fixtures.controlSources() {
            for type in try Fixtures.nodeTypes(in: source).sorted()
            where !Fixtures.notViews.contains(type) {
                XCTAssertTrue(covered.contains(type), """
                    \(source) describes \(type), which has no case in \
                    ControlTests.

                    Every control is built here with everything it can do, and \
                    the message is kept in fixtures/controls/ for the C# tests \
                    to apply. A control without one is a control nothing checks \
                    the renderer against.
                    """)
            }
        }
    }

    /// The shared tier, deliberately covered in one place rather than in every
    /// control's case.
    func testTheSharedTierIsCoveredOnce() throws {
        let tiers = try XCTUnwrap(Self.cases.first { $0.source == "Elements.swift" })
        let declared = try Fixtures.propertyKeys(in: "Elements.swift")

        // Worth stating rather than implying: this is a real number of
        // properties, and it is covered once.
        XCTAssertGreaterThan(declared.count, 30)
        XCTAssertEqual(Self.propNames(in: tiers.node).intersection(declared), declared)
    }

    // MARK: - Two-way inputs

    /// A binding is what a two-way input IS: the property, and a handler that
    /// writes what came back.
    func testATwoWayInputWritesBackWhatArrives() {
        let text = State("")
        let toggled = State(false)
        let volume = State(0.0)
        let size = State(0)
        let due = State(CalendarDate(year: 2026, month: 1, day: 1))
        let ticked = State(false)
        let chosen = State(false)
        let servings = State(0.0)
        let query = State("")
        let alarm = State(ClockTime(hour: 0, minute: 0))
        let refreshing = State(false)

        let renders = Renders()
        let patch = renders.render(Node(type: "VerticalStackLayout", children: [
            Entry(text.projectedValue).body,
            Editor(text.projectedValue).id("editor").body,
            Switch(toggled.projectedValue).body,
            Slider(volume.projectedValue).body,
            Picker(["S", "M", "L"]).selectedIndex(size.projectedValue).body,
            DatePicker(due.projectedValue).body,
            CheckBox(ticked.projectedValue).id("checkBox").body,
            RadioButton("Medium").isChecked(chosen.projectedValue).id("radio").body,
            Stepper(servings.projectedValue).id("stepper").body,
            SearchBar(query.projectedValue).id("search").body,
            TimePicker(alarm.projectedValue).id("time").body,
            RefreshView(refreshing.projectedValue) { Label("rows") }.id("refresh").body,
        ]))

        renders.fire(handler(patch.children[0], "textChanged"), with: [.string("Ada")])
        renders.fire(handler(patch.child("editor"), "textChanged"), with: [.string("Notes")])
        renders.fire(handler(patch.children[2], "toggled"), with: [.bool(true)])
        renders.fire(handler(patch.children[3], "valueChanged"), with: [.number(12.5)])
        renders.fire(handler(patch.children[4], "selectedIndexChanged"), with: [.number(2)])
        renders.fire(handler(patch.children[5], "dateSelected"), with: [.numbers([2026, 8, 2])])
        renders.fire(handler(patch.child("checkBox"), "checkedChanged"), with: [.bool(true)])
        renders.fire(handler(patch.child("radio"), "checkedChanged"), with: [.bool(true)])
        renders.fire(handler(patch.child("stepper"), "valueChanged"), with: [.number(4)])
        renders.fire(handler(patch.child("search"), "textChanged"), with: [.string("al")])
        renders.fire(handler(patch.child("time"), "timeSelected"), with: [.numbers([9, 30, 0])])

        // Not an event: MAUI has none for IsRefreshing, so the write-back comes
        // through the property watch - which is the other half of the same rule.
        renders.fire(handler(patch.child("refresh"), "isRefreshingChanged"), with: [.bool(true)])

        XCTAssertEqual(text.wrappedValue, "Notes")
        XCTAssertTrue(toggled.wrappedValue)
        XCTAssertEqual(volume.wrappedValue, 12.5)
        XCTAssertEqual(size.wrappedValue, 2)
        XCTAssertEqual(due.wrappedValue, CalendarDate(year: 2026, month: 8, day: 2))
        XCTAssertTrue(ticked.wrappedValue)
        XCTAssertTrue(chosen.wrappedValue)
        XCTAssertEqual(servings.wrappedValue, 4)
        XCTAssertEqual(query.wrappedValue, "al")
        XCTAssertEqual(alarm.wrappedValue, ClockTime(hour: 9, minute: 30))
        XCTAssertTrue(refreshing.wrappedValue)
    }

    /// A radio button hears its own CLEARING as well: MAUI reports both sides of
    /// a change of mind, so the button that lost writes false through its own
    /// binding.
    func testARadioButtonThatLosesTheGroupWritesBackFalse() {
        let chosen = State(true)

        let renders = Renders()
        let patch = renders.render(
            RadioButton("Medium")
                .isChecked(chosen.projectedValue)
                .groupName("size")
                .body)

        renders.fire(handler(patch, "checkedChanged"), with: [.bool(false)])

        XCTAssertFalse(chosen.wrappedValue)
    }

    /// A time of day READS AND WRITES its text form, which is a convenience for
    /// an author and not the form it travels in: on the wire it is its numbers,
    /// for the reason a date is - a formatter would mean ICU. The wire rule is
    /// `testATwoWayInputWritesBackWhatArrives`, which fires `timeSelected` with
    /// three numbers, and `fixtures/controls/TimePicker`.
    func testATimeOfDayReadsAndWritesItsTextForm() {
        XCTAssertEqual(ClockTime(hour: 9, minute: 5).text, "09:05:00")
        XCTAssertEqual(ClockTime(hour: 21, minute: 5, second: 30).text, "21:05:30")

        // Read back in the form C# sends, and in the shorter one a hand would
        // write.
        XCTAssertEqual(ClockTime("21:05:30"), ClockTime(hour: 21, minute: 5, second: 30))
        XCTAssertEqual(ClockTime("09:30"), ClockTime(hour: 9, minute: 30))

        // Nil rather than midnight, so a value that did not survive the trip is
        // visible.
        XCTAssertNil(ClockTime("half past nine"))
        XCTAssertNil(ClockTime("9"))

        XCTAssertLessThan(ClockTime(hour: 9, minute: 30), ClockTime(hour: 9, minute: 31))

        // .NET's "fff" - exactly three digits of millisecond - for text an
        // author hands in. now() answers as four numbers, not as this, and the
        // text form drops the milliseconds again on the way out.
        XCTAssertEqual(
            ClockTime("21:05:30.125"),
            ClockTime(hour: 21, minute: 5, second: 30, millisecond: 125))
        XCTAssertEqual(ClockTime(hour: 9, minute: 5, second: 1, millisecond: 500).text, "09:05:01")
        XCTAssertNil(ClockTime("21:05:30.12"), "two digits is a truncated value, not 120ms")
        XCTAssertNil(ClockTime("21:05:30.abc"))

        XCTAssertLessThan(
            ClockTime(hour: 9, minute: 30, second: 1, millisecond: 100),
            ClockTime(hour: 9, minute: 30, second: 1, millisecond: 200))
    }

    /// The rule that makes the two forms mix: a typed handler written after a
    /// binding runs BESIDE the binding's write, not instead of it.
    ///
    /// A handler that REPLACED it would stop the field reporting anything
    /// without a word - which is why the typed modifiers go through
    /// `addHandler`, and why nothing public replaces a handler at all.
    func testATypedHandlerRunsBesideTheBindingRatherThanReplacingIt() {
        let text = State("")
        var seen: [String] = []

        let renders = Renders()
        let patch = renders.render(
            Entry(text.projectedValue)
                .onTextChanged { seen.append($0) }
                .body)

        renders.fire(handler(patch, "textChanged"), with: [.string("Ada")])

        XCTAssertEqual(text.wrappedValue, "Ada")
        XCTAssertEqual(seen, ["Ada"])
    }

    /// The same rule in the other order, where it used to break: the binding
    /// written AFTER the handler must not replace it. The Picker's binding
    /// stored its write-back directly for a while, and
    /// `.onSelectedIndexChanged { } .selectedIndex($size)` killed the handler
    /// without a word.
    func testABindingWrittenAfterAHandlerRunsBesideIt() {
        let size = State(0)
        var seen: [Int] = []
        var stateAsTheHandlerRan: [Int] = []

        let renders = Renders()
        let patch = renders.render(
            Picker(["S", "M", "L"])
                .onSelectedIndexChanged {
                    seen.append($0)
                    stateAsTheHandlerRan.append(size.wrappedValue)
                }
                .selectedIndex(size.projectedValue)
                .body)

        renders.fire(handler(patch, "selectedIndexChanged"), with: [.number(2)])

        XCTAssertEqual(size.wrappedValue, 2)
        XCTAssertEqual(seen, [2])

        // Handlers run in WRITING order, so a handler written BEFORE the
        // binding runs before its write and reads the OLD state - which is
        // what the doc comments promise, and why the payload matters.
        XCTAssertEqual(stateAsTheHandlerRan, [0])
    }

    /// A second handler for the same event runs beside the first - on a Button
    /// too, which reached for the replacing primitive for a while and ran only
    /// the last one written.
    func testASecondHandlerRunsBesideTheFirst() {
        var seen: [String] = []

        let renders = Renders()
        let patch = renders.render(
            Button("Save")
                .onClicked { seen.append("first") }
                .onClicked { seen.append("second") }
                .body)

        renders.fire(handler(patch, "clicked"))

        XCTAssertEqual(seen, ["first", "second"],
            "Both handlers run, in the order they were written.")
    }

    /// The same promise on the non-view items, which each carry their typed
    /// event modifier by hand: for a while those ASSIGNED the handler, so a
    /// second one silently replaced the first while "every typed event
    /// modifier composes" stood written on Button. A ToolbarItem and a Pin
    /// stand for the family - MenuItem, MenuFlyoutItem and SwipeItem are the
    /// same two lines.
    func testASecondHandlerOnAnItemRunsBesideTheFirst() {
        var seen: [String] = []

        let renders = Renders()
        let bar = renders.render(
            ToolbarItem("Save")
                .onClicked { seen.append("first") }
                .onClicked { seen.append("second") }
                .body)

        renders.fire(handler(bar, "clicked"))

        XCTAssertEqual(seen, ["first", "second"])

        seen = []
        let pin = renders.render(
            Pin("Office")
                .onMarkerClicked { seen.append("first") }
                .onMarkerClicked { seen.append("second") }
                .body)

        renders.fire(handler(pin, "markerClicked"))

        XCTAssertEqual(seen, ["first", "second"])
    }

    /// A payload of the wrong KIND leaves the handler AND the binding alone -
    /// the rule every gesture follows, now on the typed value events too.
    /// Nothing is parsed anywhere: the value arrives under its tag and the
    /// typed accessor answers nil for every other arm. -1 is a real index
    /// (nothing chosen), so it cannot stand in for "unreadable" either.
    func testAPayloadOfTheWrongKindLeavesTheHandlerAlone() {
        let size = State(1)
        var seen: [Int] = []

        let renders = Renders()
        let patch = renders.render(
            Picker(["S", "M", "L"])
                .selectedIndex(size.projectedValue)
                .onSelectedIndexChanged { seen.append($0) }
                .body)

        renders.fire(handler(patch, "selectedIndexChanged"), with: [.string("not-a-number")])

        XCTAssertEqual(size.wrappedValue, 1)
        XCTAssertEqual(seen, [])
    }
    /// A value MAUI only reports - ScrollY has no setter worth writing to - goes
    /// one way, into the binding.
    func testAReportedPropertyWritesIntoItsBinding() {
        let scrolled = State(0.0)

        let renders = Renders()
        let patch = renders.render(
            ScrollView {
                Label("content")
            }
            .scrollY(scrolled.projectedValue)
            .body)

        renders.fire(handler(patch, "scrollYChanged"), with: [.number(120)])

        XCTAssertEqual(scrolled.wrappedValue, 120)
    }

    /// A number crosses as its own bits, so no locale can garble it on the
    /// way and there is nothing here to parse. What is left to get wrong is the
    /// SHAPE: a payload that is not a number leaves the binding alone rather
    /// than landing on a zero nobody dragged to - which is why the value fired
    /// is text that LOOKS like a number under some separator.
    func testAValueOfTheWrongKindLeavesTheBindingAlone() {
        let volume = State(0.0)

        let renders = Renders()
        let patch = renders.render(Slider(volume.projectedValue).body)

        renders.fire(handler(patch, "valueChanged"), with: [.string("12,5")])

        XCTAssertEqual(volume.wrappedValue, 0)
    }

    /// A navigation MAUI gives no reason for still reports, because the url
    /// and the outcome beside it are perfectly good.
    ///
    /// Measured on Windows 11 arm64, 2026-08-13: a WebView's FIRST navigation
    /// - the source it was handed before its browser existed - arrives with a
    /// `NavigationEvent` MAUI declares no member for, and the host has nothing
    /// to translate it onto but `.unknown`. Refusing that report would leave a
    /// page loaded on screen while the interface still said nothing had, with
    /// only a second navigation ever reporting. An unknown member degrades; a
    /// wrong SHAPE still refuses, which is the test below.
    func testANavigationWithNoReasonStillReports() {
        var seen: [WebNavigated] = []

        let renders = Renders()
        let patch = renders.render(
            WebView("https://example.com")
                .onNavigated { seen.append($0) }
                .body)

        renders.fire(handler(patch, "navigated"), with: [
            .enumeration(WebNavigationResult.success.rawValue),
            .enumeration(WebNavigationEvent.unknown.rawValue),
            .string("https://example.com/"),
        ])

        XCTAssertEqual(seen.count, 1)
        XCTAssertEqual(seen.first?.result, .success)
        XCTAssertEqual(seen.first?.event, .unknown)
        XCTAssertEqual(seen.first?.url, "https://example.com/")

        // `.unknown` is what this platform actually reports, and it has a case
        // of its own; the RULE is wider than that one member, so a number
        // neither side declares reads as unknown too rather than taking the
        // report down with it.
        renders.fire(handler(patch, "navigated"),
            with: [.enumeration(9), .enumeration(9), .string("https://example.com/")])

        XCTAssertEqual(seen.count, 2)
        XCTAssertEqual(seen.last?.result, .unknown)
        XCTAssertEqual(seen.last?.event, .unknown)
    }

    /// The other half of the same rule: a value of the wrong KIND is a
    /// garbled payload rather than a reason MAUI left out, so nothing runs -
    /// a report invented from rubbish is worse than a report not made.
    func testANavigationReportOfTheWrongShapeLeavesTheHandlerAlone() {
        var seen: [WebNavigation] = []

        let renders = Renders()
        let patch = renders.render(
            WebView("https://example.com")
                .onNavigating { seen.append($0) }
                .body)

        // The reason as a plain NUMBER where a member is wanted - what a host
        // that stopped translating would send.
        renders.fire(handler(patch, "navigating"), with: [
            .number(Double(WebNavigationEvent.newPage.rawValue)),
            .string("https://example.com/"),
        ])

        XCTAssertTrue(seen.isEmpty)
    }

    // MARK: - Support

    private func handler(_ patch: Patch?, _ event: Event) -> Int {
        patch?.events?[event] ?? -1
    }

    /// Every property name in a tree, the case's own and its children's.
    private static func propNames(in node: Node) -> Set<String> {
        node.children.reduce(into: Set(node.props.keys.map(\.name))) { names, child in
            names.formUnion(propNames(in: child))
        }
    }
}
