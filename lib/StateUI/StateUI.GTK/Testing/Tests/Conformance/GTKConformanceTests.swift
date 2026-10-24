// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@_spi(Host) import StateUIConformance
import Foundation
@testable import StateUIGTKDriver
import XCTest

/// The conformance suite on GTK: a family a contract, each one test, its verdicts GTK's column of the
/// control dictionary.
@MainActor
final class GTKConformanceTests: XCTestCase {
    override func setUp() async throws {
        onUIThread { GTKBackends.registered }
    }

    func testSpinner() { conform(SpinnerTests.self) }
    func testButton() { conform(ButtonTests.self) }
    func testCanvas() { conform(CanvasTests.self) }
    func testCapsule() { conform(CapsuleTests.self) }
    func testFill() { conform(FillTests.self) }
    func testLayoutEngine() { conform(LayoutEngineTests.self) }
    func testCheckBox() { conform(CheckBoxTests.self) }
    func testSpace() { conform(SpaceTests.self) }
    func testDatePicker() { conform(DatePickerTests.self) }
    func testEllipse() { conform(EllipseTests.self) }
    func testGrid() { conform(GridTests.self) }
    func testHStack() { conform(HStackTests.self) }
    func testImage() { conform(ImageTests.self) }
    func testText() { conform(TextTests.self) }
    func testLine() { conform(LineTests.self) }
    func testMap() { conform(MapTests.self) }
    func testPath() { conform(PathTests.self) }
    func testPicker() { conform(PickerTests.self) }
    func testPolygon() { conform(PolygonTests.self) }
    func testPolyline() { conform(PolylineTests.self) }
    func testProgressBar() { conform(ProgressBarTests.self) }
    func testRectangle() { conform(RectangleTests.self) }
    func testScrollView() { conform(ScrollViewTests.self) }
    func testItemsView() { conform(ItemsViewTests.self) }
    func testSearchField() { conform(SearchFieldTests.self) }
    func testSlider() { conform(SliderTests.self) }
    func testStepper() { conform(StepperTests.self) }
    func testSwitch() { conform(SwitchTests.self) }
    func testTextEditor() { conform(TextEditorTests.self) }
    func testTextField() { conform(TextFieldTests.self) }
    func testTimePicker() { conform(TimePickerTests.self) }
    func testVStack() { conform(VStackTests.self) }
    func testWebView() { conform(WebViewTests.self) }
    func testZStack() { conform(ZStackTests.self) }
    func testApplication() { conform(ApplicationTests.self) }
    func testContextMenu() { conform(ContextMenuTests.self) }
    func testPopover() { conform(PopoverTests.self) }
    func testButtonMenu() { conform(ButtonMenuTests.self) }
    func testMenu() { conform(MenuTests.self) }
    func testMenuBar() { conform(MenuBarTests.self) }
    func testMenuItem() { conform(MenuItemTests.self) }
    func testMenuToggle() { conform(MenuToggleTests.self) }
    func testSeparator() { conform(SeparatorTests.self) }
    func testMenuSeparator() { conform(MenuSeparatorTests.self) }
    func testAnchor() { conform(AnchorTests.self) }
    func testSheet() { conform(SheetTests.self) }
    func testNavigationStack() { conform(NavigationStackTests.self) }
    func testOverlay() { conform(OverlayTests.self) }
    func testPage() { conform(PageTests.self) }
    func testMarker() { conform(MarkerTests.self) }
    func testScene() { conform(SceneTests.self) }
    func testTextSpan() { conform(TextSpanTests.self) }
    func testTextSpans() { conform(TextSpansTests.self) }
    func testSplitView() { conform(SplitViewTests.self) }
    func testTabView() { conform(TabViewTests.self) }
    func testTitleView() { conform(TitleViewTests.self) }
    func testToolbarButton() { conform(ToolbarButtonTests.self) }
    func testToolbarGroup() { conform(ToolbarGroupTests.self) }
    func testToolbarToggle() { conform(ToolbarToggleTests.self) }
    func testWindow() { conform(WindowTests.self) }
    func testAutomationElement() { conform(AutomationElementTests.self) }
    func testVisualElement() { conform(VisualElementTests.self) }
    func testView() { conform(ViewTests.self) }
    func testLayout() { conform(LayoutTests.self) }
    func testStack() { conform(StackTests.self) }
    func testTextInput() { conform(TextInputTests.self) }
    func testShape() { conform(ShapeTests.self) }
    func testFilledShape() { conform(FilledShapeTests.self) }
    func testCorneredShape() { conform(CorneredShapeTests.self) }
    func testTextualElement() { conform(TextualElementTests.self) }
    func testTextColorElement() { conform(TextColorElementTests.self) }
    func testFontElement() { conform(FontElementTests.self) }
    func testTextAlignmentElement() { conform(TextAlignmentElementTests.self) }
    func testLineHeightElement() { conform(LineHeightElementTests.self) }
    func testTrackingElement() { conform(TrackingElementTests.self) }
    func testDecorableTextElement() { conform(DecorableTextElementTests.self) }
    func testPaddingElement() { conform(PaddingElementTests.self) }
    func testBorderElement() { conform(BorderElementTests.self) }
    func testImageElement() { conform(ImageElementTests.self) }
    func testTintElement() { conform(TintElementTests.self) }
    func testKeyboardElement() { conform(KeyboardElementTests.self) }
    func testFocusElement() { conform(FocusElementTests.self) }
    func testRefreshElement() { conform(RefreshElementTests.self) }
    func testBarElement() { conform(BarElementTests.self) }
    func testMenuItemElement() { conform(MenuItemElementTests.self) }
    func testActionElement() { conform(ActionElementTests.self) }
    func testButtonMenuElement() { conform(ButtonMenuElementTests.self) }
    func testLink() { conform(LinkTests.self) }
    func testTextAndIconElement() { conform(TextAndIconElementTests.self) }
    func testPageElement() { conform(PageElementTests.self) }

    /// Runs `family` on GTK, and holds its verdicts to the family's file of GTK's marks.
    private func conform(_ family: any ConformanceFamily.Type) {
        onUIThread { GTKExports.conform(family) }
    }
}
