// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHostConformance
import WinSDK
import XCTest

/// The conformance suite on WinUI: a family a contract, each one test, its verdicts WinUI's column of the
/// control dictionary.
final class WinUIConformanceTests: XCTestCase {
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
    func testLabel() { conform(LabelTests.self) }
    func testLine() { conform(LineTests.self) }
    func testMap() { conform(MapTests.self) }
    func testPath() { conform(PathTests.self) }
    func testPicker() { conform(PickerTests.self) }
    func testPolygon() { conform(PolygonTests.self) }
    func testPolyline() { conform(PolylineTests.self) }
    func testPositionIndicator() { conform(PositionIndicatorTests.self) }
    func testProgressBar() { conform(ProgressBarTests.self) }
    func testRadioButton() { conform(RadioButtonTests.self) }
    func testRectangle() { conform(RectangleTests.self) }
    func testScrollView() { conform(ScrollViewTests.self) }
    func testSearchField() { conform(SearchFieldTests.self) }
    func testSlider() { conform(SliderTests.self) }
    func testStepper() { conform(StepperTests.self) }
    func testSwitch() { conform(SwitchTests.self) }
    func testTextEditor() { conform(TextEditorTests.self) }
    func testTextField() { conform(TextFieldTests.self) }
    func testTimePicker() { conform(TimePickerTests.self) }
    func testTitleBar() { conform(TitleBarTests.self) }
    func testVStack() { conform(VStackTests.self) }
    func testWebView() { conform(WebViewTests.self) }
    func testZStack() { conform(ZStackTests.self) }
    func testApplication() { conform(ApplicationTests.self) }
    func testContent() { conform(ContentTests.self) }
    func testContextMenu() { conform(ContextMenuTests.self) }
    func testLeadingContent() { conform(LeadingContentTests.self) }
    func testMenu() { conform(MenuTests.self) }
    func testMenuBar() { conform(MenuBarTests.self) }
    func testMenuItem() { conform(MenuItemTests.self) }
    func testMenuSeparator() { conform(MenuSeparatorTests.self) }
    func testModalStack() { conform(ModalStackTests.self) }
    func testNavigationStack() { conform(NavigationStackTests.self) }
    func testOverlay() { conform(OverlayTests.self) }
    func testPage() { conform(PageTests.self) }
    func testPin() { conform(PinTests.self) }
    func testScene() { conform(SceneTests.self) }
    func testSpan() { conform(SpanTests.self) }
    func testSpans() { conform(SpansTests.self) }
    func testSplitView() { conform(SplitViewTests.self) }
    func testTabbedView() { conform(TabbedViewTests.self) }
    func testTitleView() { conform(TitleViewTests.self) }
    func testToolbarItem() { conform(ToolbarItemTests.self) }
    func testToolbarItems() { conform(ToolbarItemsTests.self) }
    func testTrailingContent() { conform(TrailingContentTests.self) }
    func testWindow() { conform(WindowTests.self) }
    func testPropertyContainer() { conform(PropertyContainerTests.self) }
    func testVisualElement1() { conform(VisualElementTests.self, part: Conformance.Part(1, of: 4)) }
    func testVisualElement2() { conform(VisualElementTests.self, part: Conformance.Part(2, of: 4)) }
    func testVisualElement3() { conform(VisualElementTests.self, part: Conformance.Part(3, of: 4)) }
    func testVisualElement4() { conform(VisualElementTests.self, part: Conformance.Part(4, of: 4)) }
    func testView1() { conform(ViewTests.self, part: Conformance.Part(1, of: 3)) }
    func testView2() { conform(ViewTests.self, part: Conformance.Part(2, of: 3)) }
    func testView3() { conform(ViewTests.self, part: Conformance.Part(3, of: 3)) }
    func testLayout() { conform(LayoutTests.self) }
    func testStackBase() { conform(StackBaseTests.self) }
    func testInputView() { conform(InputViewTests.self) }
    func testShape() { conform(ShapeTests.self) }
    func testTextElement() { conform(TextElementTests.self) }
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

    /// Runs `family` - or `part` of it - on WinUI, and holds its verdicts to its file of WinUI's marks. A test runs
    /// in a process of its own, whose GDI objects - some forty left by every window a case shows - stay well below
    /// the ten thousand a process holds; a family past that runs in more parts.
    /// Design: docs/design/platforms/winui/conformance.md#a-process-a-test
    private func conform(_ family: any ConformanceFamily.Type, part: Conformance.Part = .whole) {
        let verdicts = onUIThread {
            Conformance.run(
                family, part: part, on: WinUIDriver(), report: { XCTFail($0.message, file: $0.file, line: $0.line) },
                log: { print($0) })
        }
        let file = part == .whole ? family.name : "\(family.name)-\(part.number)"
        XCTAssertNoThrow(try WinUIExports.hold(HostVerdict.text(verdicts), at: "marks/winui/\(file).txt"))
        XCTAssertLessThan(GetGuiResources(GetCurrentProcess(), DWORD(GR_GDIOBJECTS)), 6_000,
                          "\(family.name) shows too many windows for one process: run it in more parts")
    }
}
