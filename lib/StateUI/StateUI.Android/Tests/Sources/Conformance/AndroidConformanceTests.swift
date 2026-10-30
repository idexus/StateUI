// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Android
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
@_spi(Host) import StateUIConformance
import XCTest

/// The conformance suite on Android Views: a family a contract, each one test, its verdicts Android's column of the
/// control dictionary - written into the test APK's files, where `test-android.sh` holds `lib/StateUI/exports/` to them.
final class AndroidConformanceTests: XCTestCase {
    static var allTests: [(String, (AndroidConformanceTests) -> () throws -> Void)] {
        [
            ("testSpinner", testSpinner),
            ("testButton", testButton),
            ("testCanvas", testCanvas),
            ("testCapsule", testCapsule),
            ("testFill", testFill),
            ("testMotionLayout", testMotionLayout),
            ("testCheckBox", testCheckBox),
            ("testColorPicker", testColorPicker),
            ("testDatePicker", testDatePicker),
            ("testEllipse", testEllipse),
            ("testGrid", testGrid),
            ("testHStack", testHStack),
            ("testImage", testImage),
            ("testText", testText),
            ("testLine", testLine),
            ("testMap", testMap),
            ("testPath", testPath),
            ("testPicker", testPicker),
            ("testPolygon", testPolygon),
            ("testPolyline", testPolyline),
            ("testProgressBar", testProgressBar),
            ("testRectangle", testRectangle),
            ("testScrollView", testScrollView),
            ("testItemsView", testItemsView),
            ("testSearchField", testSearchField),
            ("testSlider", testSlider),
            ("testSpace", testSpace),
            ("testStepper", testStepper),
            ("testSwitch", testSwitch),
            ("testTextEditor", testTextEditor),
            ("testTextField", testTextField),
            ("testTimePicker", testTimePicker),
            ("testVStack", testVStack),
            ("testWebView", testWebView),
            ("testZStack", testZStack),
            ("testApplication", testApplication),
            ("testContextMenu", testContextMenu),
            ("testPopover", testPopover),
            ("testButtonMenu", testButtonMenu),
            ("testMenu", testMenu),
            ("testMenuBar", testMenuBar),
            ("testMenuItem", testMenuItem),
            ("testMenuToggle", testMenuToggle),
            ("testSeparator", testSeparator),
            ("testMenuSeparator", testMenuSeparator),
            ("testAnchor", testAnchor),
            ("testSheet", testSheet),
            ("testNavigationStack", testNavigationStack),
            ("testOverlay", testOverlay),
            ("testBottomBar", testBottomBar),
            ("testPage", testPage),
            ("testMarker", testMarker),
            ("testScene", testScene),
            ("testTextSpan", testTextSpan),
            ("testTextSpans", testTextSpans),
            ("testSplitView", testSplitView),
            ("testTabView", testTabView),
            ("testTitleView", testTitleView),
            ("testToolbarButton", testToolbarButton),
            ("testToolbarGroup", testToolbarGroup),
            ("testToolbarLabel", testToolbarLabel),
            ("testToolbarToggle", testToolbarToggle),
            ("testWindow", testWindow),
            ("testAutomationElement", testAutomationElement),
            ("testVisualElement", testVisualElement),
            ("testView", testView),
            ("testLayout", testLayout),
            ("testStack", testStack),
            ("testTextInput", testTextInput),
            ("testShape", testShape),
            ("testFilledShape", testFilledShape),
            ("testCorneredShape", testCorneredShape),
            ("testTextualElement", testTextualElement),
            ("testTextColorElement", testTextColorElement),
            ("testFontElement", testFontElement),
            ("testTextAlignmentElement", testTextAlignmentElement),
            ("testLineHeightElement", testLineHeightElement),
            ("testTrackingElement", testTrackingElement),
            ("testDecorableTextElement", testDecorableTextElement),
            ("testPaddingElement", testPaddingElement),
            ("testBorderElement", testBorderElement),
            ("testImageElement", testImageElement),
            ("testTintElement", testTintElement),
            ("testKeyboardElement", testKeyboardElement),
            ("testFocusElement", testFocusElement),
            ("testRefreshElement", testRefreshElement),
            ("testBarElement", testBarElement),
            ("testBarItemElement", testBarItemElement),
            ("testBarButtonElement", testBarButtonElement),
            ("testMenuItemElement", testMenuItemElement),
            ("testActionElement", testActionElement),
            ("testButtonMenuElement", testButtonMenuElement),
            ("testLink", testLink),
            ("testTextAndIconElement", testTextAndIconElement),
            ("testPageElement", testPageElement),
            ("testAWindowsPhaseIsTheHostsOwnOnAWindowAlone", testAWindowsPhaseIsTheHostsOwnOnAWindowAlone),
        ]
    }

    func testSpinner() throws { try conform(SpinnerTests.self) }
    func testButton() throws { try conform(ButtonTests.self) }
    func testCanvas() throws { try conform(CanvasTests.self) }
    func testCapsule() throws { try conform(CapsuleTests.self) }
    func testFill() throws { try conform(FillTests.self) }
    func testMotionLayout() throws { try conform(MotionLayoutTests.self) }
    func testCheckBox() throws { try conform(CheckBoxTests.self) }
    func testColorPicker() throws { try conform(ColorPickerTests.self) }
    func testSpace() throws { try conform(SpaceTests.self) }
    func testDatePicker() throws { try conform(DatePickerTests.self) }
    func testEllipse() throws { try conform(EllipseTests.self) }
    func testGrid() throws { try conform(GridTests.self) }
    func testHStack() throws { try conform(HStackTests.self) }
    func testImage() throws { try conform(ImageTests.self) }
    func testText() throws { try conform(TextTests.self) }
    func testLine() throws { try conform(LineTests.self) }
    func testMap() throws { try conform(MapTests.self) }
    func testPath() throws { try conform(PathTests.self) }
    func testPicker() throws { try conform(PickerTests.self) }
    func testPolygon() throws { try conform(PolygonTests.self) }
    func testPolyline() throws { try conform(PolylineTests.self) }
    func testProgressBar() throws { try conform(ProgressBarTests.self) }
    func testRectangle() throws { try conform(RectangleTests.self) }
    func testScrollView() throws { try conform(ScrollViewTests.self) }
    func testItemsView() throws { try conform(ItemsViewTests.self) }
    func testSearchField() throws { try conform(SearchFieldTests.self) }
    func testSlider() throws { try conform(SliderTests.self) }
    func testStepper() throws { try conform(StepperTests.self) }
    func testSwitch() throws { try conform(SwitchTests.self) }
    func testTextEditor() throws { try conform(TextEditorTests.self) }
    func testTextField() throws { try conform(TextFieldTests.self) }
    func testTimePicker() throws { try conform(TimePickerTests.self) }
    func testVStack() throws { try conform(VStackTests.self) }
    func testWebView() throws { try conform(WebViewTests.self) }
    func testZStack() throws { try conform(ZStackTests.self) }
    func testApplication() throws { try conform(ApplicationTests.self) }
    func testContextMenu() throws { try conform(ContextMenuTests.self) }
    func testPopover() throws { try conform(PopoverTests.self) }
    func testButtonMenu() throws { try conform(ButtonMenuTests.self) }
    func testMenu() throws { try conform(MenuTests.self) }
    func testMenuBar() throws { try conform(MenuBarTests.self) }
    func testMenuItem() throws { try conform(MenuItemTests.self) }
    func testMenuToggle() throws { try conform(MenuToggleTests.self) }
    func testSeparator() throws { try conform(SeparatorTests.self) }
    func testMenuSeparator() throws { try conform(MenuSeparatorTests.self) }
    func testAnchor() throws { try conform(AnchorTests.self) }
    func testSheet() throws { try conform(SheetTests.self) }
    func testNavigationStack() throws { try conform(NavigationStackTests.self) }
    func testOverlay() throws { try conform(OverlayTests.self) }
    func testBottomBar() throws { try conform(BottomBarTests.self) }
    func testPage() throws { try conform(PageTests.self) }
    func testMarker() throws { try conform(MarkerTests.self) }
    func testScene() throws { try conform(SceneTests.self) }
    func testTextSpan() throws { try conform(TextSpanTests.self) }
    func testTextSpans() throws { try conform(TextSpansTests.self) }
    func testSplitView() throws { try conform(SplitViewTests.self) }
    func testTabView() throws { try conform(TabViewTests.self) }
    func testTitleView() throws { try conform(TitleViewTests.self) }
    func testToolbarButton() throws { try conform(ToolbarButtonTests.self) }
    func testToolbarGroup() throws { try conform(ToolbarGroupTests.self) }
    func testToolbarLabel() throws { try conform(ToolbarLabelTests.self) }
    func testToolbarToggle() throws { try conform(ToolbarToggleTests.self) }
    func testWindow() throws { try conform(WindowTests.self) }
    func testAutomationElement() throws { try conform(AutomationElementTests.self) }
    func testVisualElement() throws { try conform(VisualElementTests.self) }
    func testView() throws { try conform(ViewTests.self) }
    func testLayout() throws { try conform(LayoutTests.self) }
    func testStack() throws { try conform(StackTests.self) }
    func testTextInput() throws { try conform(TextInputTests.self) }
    func testShape() throws { try conform(ShapeTests.self) }
    func testFilledShape() throws { try conform(FilledShapeTests.self) }
    func testCorneredShape() throws { try conform(CorneredShapeTests.self) }
    func testTextualElement() throws { try conform(TextualElementTests.self) }
    func testTextColorElement() throws { try conform(TextColorElementTests.self) }
    func testFontElement() throws { try conform(FontElementTests.self) }
    func testTextAlignmentElement() throws { try conform(TextAlignmentElementTests.self) }
    func testLineHeightElement() throws { try conform(LineHeightElementTests.self) }
    func testTrackingElement() throws { try conform(TrackingElementTests.self) }
    func testDecorableTextElement() throws { try conform(DecorableTextElementTests.self) }
    func testPaddingElement() throws { try conform(PaddingElementTests.self) }
    func testBorderElement() throws { try conform(BorderElementTests.self) }
    func testImageElement() throws { try conform(ImageElementTests.self) }
    func testTintElement() throws { try conform(TintElementTests.self) }
    func testKeyboardElement() throws { try conform(KeyboardElementTests.self) }
    func testFocusElement() throws { try conform(FocusElementTests.self) }
    func testRefreshElement() throws { try conform(RefreshElementTests.self) }
    func testBarElement() throws { try conform(BarElementTests.self) }
    func testBarItemElement() throws { try conform(BarItemElementTests.self) }
    func testBarButtonElement() throws { try conform(BarButtonElementTests.self) }
    func testMenuItemElement() throws { try conform(MenuItemElementTests.self) }
    func testActionElement() throws { try conform(ActionElementTests.self) }
    func testButtonMenuElement() throws { try conform(ButtonMenuElementTests.self) }
    func testLink() throws { try conform(LinkTests.self) }
    func testTextAndIconElement() throws { try conform(TextAndIconElementTests.self) }
    func testPageElement() throws { try conform(PageElementTests.self) }

    /// The host tells a window its activity's phase: closing or minimizing anything else is Android's own.
    func testAWindowsPhaseIsTheHostsOwnOnAWindowAlone() {
        onMainActor {
            let driver = AndroidDriver()
            XCTAssertNotNil(driver.byHost("close on Window"))
            XCTAssertNil(driver.byHost("close on Picker"))
            XCTAssertNil(driver.byHost("switchAway on Page"))
        }
    }

    /// The verdicts of a family run in parts, gathered until its last part writes them.
    nonisolated(unsafe) private static var gathered: [String: [HostVerdict]] = [:]

    /// Runs `family` - or `part` of it - on Android Views, and writes its verdicts to its file of Android's marks once
    /// its last part has run. The runner runs a long family in parts, each in a message of the UI thread of its own.
    /// Design: docs/design/platforms/android/conformance.md#a-message-an-item
    func conform(_ family: any ConformanceFamily.Type, part: Conformance.Part = .whole) throws {
        try onMainActor {
            let driver = AndroidDriver()
            let verdicts = Conformance.run(
                family, part: part, on: driver, report: { XCTFail($0.message, file: $0.file, line: $0.line) })
            driver.finish()
            let all = (Self.gathered.removeValue(forKey: family.name) ?? []) + verdicts
            guard part.number == part.count else { return Self.gathered[family.name] = all }
            try TestFiles.write(HostVerdict.text(HostVerdict.merged(all)), to: "marks/android/\(family.name).txt")
        }
    }
}
