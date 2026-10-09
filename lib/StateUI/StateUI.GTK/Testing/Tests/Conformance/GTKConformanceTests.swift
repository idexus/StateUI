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

    func testActivityIndicator() { conform(ActivityIndicatorTests.self) }
    func testButton() { conform(ButtonTests.self) }
    func testCanvas() { conform(CanvasTests.self) }
    func testCheckBox() { conform(CheckBoxTests.self) }
    func testColorBox() { conform(ColorBoxTests.self) }
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
    func testRadioButton() { conform(RadioButtonTests.self) }
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
    func testMenu() { conform(MenuTests.self) }
    func testMenuBar() { conform(MenuBarTests.self) }
    func testMenuItem() { conform(MenuItemTests.self) }
    func testDivider() { conform(DividerTests.self) }
    func testModalStack() { conform(ModalStackTests.self) }
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
    func testToolbarItem() { conform(ToolbarItemTests.self) }
    func testToolbarItemGroup() { conform(ToolbarItemGroupTests.self) }
    func testWindow() { conform(WindowTests.self) }
    func testPropertyContainer() { conform(PropertyContainerTests.self) }
    func testVisualElement() { conform(VisualElementTests.self) }
    func testView() { conform(ViewTests.self) }
    func testLayout() { conform(LayoutTests.self) }
    func testStack() { conform(StackTests.self) }
    func testTextInput() { conform(TextInputTests.self) }
    func testShape() { conform(ShapeTests.self) }
    func testTextualElement() { conform(TextualElementTests.self) }
    func testTextStyleElement() { conform(TextStyleElementTests.self) }
    func testFontElement() { conform(FontElementTests.self) }
    func testTextAlignmentElement() { conform(TextAlignmentElementTests.self) }
    func testLineHeightElement() { conform(LineHeightElementTests.self) }
    func testDecorableTextElement() { conform(DecorableTextElementTests.self) }
    func testPaddingElement() { conform(PaddingElementTests.self) }
    func testBorderElement() { conform(BorderElementTests.self) }
    func testImageElement() { conform(ImageElementTests.self) }
    func testTintElement() { conform(TintElementTests.self) }
    func testBarElement() { conform(BarElementTests.self) }
    func testMenuItemElement() { conform(MenuItemElementTests.self) }
    func testPageElement() { conform(PageElementTests.self) }

    /// Runs `family` on GTK, and holds its verdicts to the family's file of GTK's marks.
    private func conform(_ family: any ConformanceFamily.Type) {
        onUIThread { GTKExports.conform(family) }
    }
}
