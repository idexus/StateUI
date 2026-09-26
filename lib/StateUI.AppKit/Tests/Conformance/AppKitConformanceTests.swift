// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAppKit
@_spi(Host) import StateUIConformance
import XCTest

/// The conformance suite on AppKit: a family a contract, each one test, its verdicts AppKit's column of the
/// control dictionary.
final class AppKitConformanceTests: XCTestCase {
    @MainActor func testActivityIndicator() { conform(ActivityIndicatorTests.self) }
    @MainActor func testButton() { conform(ButtonTests.self) }
    @MainActor func testCanvas() { conform(CanvasTests.self) }
    @MainActor func testCheckBox() { conform(CheckBoxTests.self) }
    @MainActor func testColorBox() { conform(ColorBoxTests.self) }
    @MainActor func testDatePicker() { conform(DatePickerTests.self) }
    @MainActor func testEllipse() { conform(EllipseTests.self) }
    @MainActor func testGrid() { conform(GridTests.self) }
    @MainActor func testHStack() { conform(HStackTests.self) }
    @MainActor func testImage() { conform(ImageTests.self) }
    @MainActor func testLabel() { conform(LabelTests.self) }
    @MainActor func testLine() { conform(LineTests.self) }
    @MainActor func testMap() { conform(MapTests.self) }
    @MainActor func testPath() { conform(PathTests.self) }
    @MainActor func testPicker() { conform(PickerTests.self) }
    @MainActor func testPolygon() { conform(PolygonTests.self) }
    @MainActor func testPolyline() { conform(PolylineTests.self) }
    @MainActor func testPositionIndicator() { conform(PositionIndicatorTests.self) }
    @MainActor func testProgressBar() { conform(ProgressBarTests.self) }
    @MainActor func testRadioButton() { conform(RadioButtonTests.self) }
    @MainActor func testRectangle() { conform(RectangleTests.self) }
    @MainActor func testScrollView() { conform(ScrollViewTests.self) }
    @MainActor func testSearchField() { conform(SearchFieldTests.self) }
    @MainActor func testSlider() { conform(SliderTests.self) }
    @MainActor func testStepper() { conform(StepperTests.self) }
    @MainActor func testSwitch() { conform(SwitchTests.self) }
    @MainActor func testTextEditor() { conform(TextEditorTests.self) }
    @MainActor func testTextField() { conform(TextFieldTests.self) }
    @MainActor func testTimePicker() { conform(TimePickerTests.self) }
    @MainActor func testTitleBar() { conform(TitleBarTests.self) }
    @MainActor func testVStack() { conform(VStackTests.self) }
    @MainActor func testWebView() { conform(WebViewTests.self) }
    @MainActor func testZStack() { conform(ZStackTests.self) }
    @MainActor func testApplication() { conform(ApplicationTests.self) }
    @MainActor func testContent() { conform(ContentTests.self) }
    @MainActor func testContextMenu() { conform(ContextMenuTests.self) }
    @MainActor func testLeadingContent() { conform(LeadingContentTests.self) }
    @MainActor func testMenu() { conform(MenuTests.self) }
    @MainActor func testMenuBar() { conform(MenuBarTests.self) }
    @MainActor func testMenuItem() { conform(MenuItemTests.self) }
    @MainActor func testMenuSeparator() { conform(MenuSeparatorTests.self) }
    @MainActor func testModalStack() { conform(ModalStackTests.self) }
    @MainActor func testNavigationStack() { conform(NavigationStackTests.self) }
    @MainActor func testOverlay() { conform(OverlayTests.self) }
    @MainActor func testPage() { conform(PageTests.self) }
    @MainActor func testPin() { conform(PinTests.self) }
    @MainActor func testScene() { conform(SceneTests.self) }
    @MainActor func testSpan() { conform(SpanTests.self) }
    @MainActor func testSpans() { conform(SpansTests.self) }
    @MainActor func testSplitView() { conform(SplitViewTests.self) }
    @MainActor func testTabbedView() { conform(TabbedViewTests.self) }
    @MainActor func testTitleView() { conform(TitleViewTests.self) }
    @MainActor func testToolbarItem() { conform(ToolbarItemTests.self) }
    @MainActor func testToolbarItems() { conform(ToolbarItemsTests.self) }
    @MainActor func testTrailingContent() { conform(TrailingContentTests.self) }
    @MainActor func testWindow() { conform(WindowTests.self) }
    @MainActor func testPropertyContainer() { conform(PropertyContainerTests.self) }
    @MainActor func testVisualElement() { conform(VisualElementTests.self) }
    @MainActor func testView() { conform(ViewTests.self) }
    @MainActor func testLayout() { conform(LayoutTests.self) }
    @MainActor func testStackBase() { conform(StackBaseTests.self) }
    @MainActor func testInputView() { conform(InputViewTests.self) }
    @MainActor func testShape() { conform(ShapeTests.self) }
    @MainActor func testTextElement() { conform(TextElementTests.self) }
    @MainActor func testTextStyleElement() { conform(TextStyleElementTests.self) }
    @MainActor func testFontElement() { conform(FontElementTests.self) }
    @MainActor func testTextAlignmentElement() { conform(TextAlignmentElementTests.self) }
    @MainActor func testLineHeightElement() { conform(LineHeightElementTests.self) }
    @MainActor func testDecorableTextElement() { conform(DecorableTextElementTests.self) }
    @MainActor func testPaddingElement() { conform(PaddingElementTests.self) }
    @MainActor func testBorderElement() { conform(BorderElementTests.self) }
    @MainActor func testImageElement() { conform(ImageElementTests.self) }
    @MainActor func testTintElement() { conform(TintElementTests.self) }
    @MainActor func testBarElement() { conform(BarElementTests.self) }
    @MainActor func testMenuItemElement() { conform(MenuItemElementTests.self) }
    @MainActor func testPageElement() { conform(PageElementTests.self) }

    /// Runs `family` on AppKit, and holds its verdicts to its file of AppKit's marks.
    @MainActor
    private func conform(_ family: any ConformanceFamily.Type) {
        let driver = AppKitDriver()
        defer { driver.renderer?.closeForTesting() }
        let verdicts = Conformance.run(
            family, on: driver, report: { XCTFail($0.message, file: $0.file, line: $0.line) }, log: { print($0) })
        XCTAssertNoThrow(try AppKitExports.hold(HostVerdict.text(verdicts), at: "marks/appkit/\(family.name).txt"))
    }
}
#endif
