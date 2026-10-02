// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAppKit
@_spi(Host) import StateUIConformance
import Foundation
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
    @MainActor func testText() { conform(TextTests.self) }
    @MainActor func testLine() { conform(LineTests.self) }
    @MainActor func testMap() { conform(MapTests.self) }
    @MainActor func testPath() { conform(PathTests.self) }
    @MainActor func testPicker() { conform(PickerTests.self) }
    @MainActor func testPolygon() { conform(PolygonTests.self) }
    @MainActor func testPolyline() { conform(PolylineTests.self) }
    @MainActor func testProgressBar() { conform(ProgressBarTests.self) }
    @MainActor func testRadioButton() { conform(RadioButtonTests.self) }
    @MainActor func testRectangle() { conform(RectangleTests.self) }
    @MainActor func testScrollView() { conform(ScrollViewTests.self) }
    @MainActor func testItemsView() { conform(ItemsViewTests.self) }
    @MainActor func testSearchField() { conform(SearchFieldTests.self) }
    @MainActor func testSlider() { conform(SliderTests.self) }
    @MainActor func testStepper() { conform(StepperTests.self) }
    @MainActor func testSwitch() { conform(SwitchTests.self) }
    @MainActor func testTextEditor() { conform(TextEditorTests.self) }
    @MainActor func testTextField() { conform(TextFieldTests.self) }
    @MainActor func testTimePicker() { conform(TimePickerTests.self) }
    @MainActor func testVStack() { conform(VStackTests.self) }
    @MainActor func testWebView() { conform(WebViewTests.self) }
    @MainActor func testZStack() { conform(ZStackTests.self) }
    @MainActor func testApplication() { conform(ApplicationTests.self) }
    @MainActor func testContextMenu() { conform(ContextMenuTests.self) }
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
    @MainActor func testWindow() { conform(WindowTests.self) }
    @MainActor func testPropertyContainer() { conform(PropertyContainerTests.self) }
    @MainActor func testVisualElement1() { conform(VisualElementTests.self, part: Conformance.Part(1, of: 24)) }
    @MainActor func testVisualElement2() { conform(VisualElementTests.self, part: Conformance.Part(2, of: 24)) }
    @MainActor func testVisualElement3() { conform(VisualElementTests.self, part: Conformance.Part(3, of: 24)) }
    @MainActor func testVisualElement4() { conform(VisualElementTests.self, part: Conformance.Part(4, of: 24)) }
    @MainActor func testVisualElement5() { conform(VisualElementTests.self, part: Conformance.Part(5, of: 24)) }
    @MainActor func testVisualElement6() { conform(VisualElementTests.self, part: Conformance.Part(6, of: 24)) }
    @MainActor func testVisualElement7() { conform(VisualElementTests.self, part: Conformance.Part(7, of: 24)) }
    @MainActor func testVisualElement8() { conform(VisualElementTests.self, part: Conformance.Part(8, of: 24)) }
    @MainActor func testVisualElement9() { conform(VisualElementTests.self, part: Conformance.Part(9, of: 24)) }
    @MainActor func testVisualElement10() { conform(VisualElementTests.self, part: Conformance.Part(10, of: 24)) }
    @MainActor func testVisualElement11() { conform(VisualElementTests.self, part: Conformance.Part(11, of: 24)) }
    @MainActor func testVisualElement12() { conform(VisualElementTests.self, part: Conformance.Part(12, of: 24)) }
    @MainActor func testVisualElement13() { conform(VisualElementTests.self, part: Conformance.Part(13, of: 24)) }
    @MainActor func testVisualElement14() { conform(VisualElementTests.self, part: Conformance.Part(14, of: 24)) }
    @MainActor func testVisualElement15() { conform(VisualElementTests.self, part: Conformance.Part(15, of: 24)) }
    @MainActor func testVisualElement16() { conform(VisualElementTests.self, part: Conformance.Part(16, of: 24)) }
    @MainActor func testVisualElement17() { conform(VisualElementTests.self, part: Conformance.Part(17, of: 24)) }
    @MainActor func testVisualElement18() { conform(VisualElementTests.self, part: Conformance.Part(18, of: 24)) }
    @MainActor func testVisualElement19() { conform(VisualElementTests.self, part: Conformance.Part(19, of: 24)) }
    @MainActor func testVisualElement20() { conform(VisualElementTests.self, part: Conformance.Part(20, of: 24)) }
    @MainActor func testVisualElement21() { conform(VisualElementTests.self, part: Conformance.Part(21, of: 24)) }
    @MainActor func testVisualElement22() { conform(VisualElementTests.self, part: Conformance.Part(22, of: 24)) }
    @MainActor func testVisualElement23() { conform(VisualElementTests.self, part: Conformance.Part(23, of: 24)) }
    @MainActor func testVisualElement24() { conform(VisualElementTests.self, part: Conformance.Part(24, of: 24)) }
    @MainActor func testView1() { conform(ViewTests.self, part: Conformance.Part(1, of: 11)) }
    @MainActor func testView2() { conform(ViewTests.self, part: Conformance.Part(2, of: 11)) }
    @MainActor func testView3() { conform(ViewTests.self, part: Conformance.Part(3, of: 11)) }
    @MainActor func testView4() { conform(ViewTests.self, part: Conformance.Part(4, of: 11)) }
    @MainActor func testView5() { conform(ViewTests.self, part: Conformance.Part(5, of: 11)) }
    @MainActor func testView6() { conform(ViewTests.self, part: Conformance.Part(6, of: 11)) }
    @MainActor func testView7() { conform(ViewTests.self, part: Conformance.Part(7, of: 11)) }
    @MainActor func testView8() { conform(ViewTests.self, part: Conformance.Part(8, of: 11)) }
    @MainActor func testView9() { conform(ViewTests.self, part: Conformance.Part(9, of: 11)) }
    @MainActor func testView10() { conform(ViewTests.self, part: Conformance.Part(10, of: 11)) }
    @MainActor func testView11() { conform(ViewTests.self, part: Conformance.Part(11, of: 11)) }
    @MainActor func testLayout() { conform(LayoutTests.self) }
    @MainActor func testStackBase() { conform(StackBaseTests.self) }
    @MainActor func testInputView() { conform(InputViewTests.self) }
    @MainActor func testShape1() { conform(ShapeTests.self, part: Conformance.Part(1, of: 3)) }
    @MainActor func testShape2() { conform(ShapeTests.self, part: Conformance.Part(2, of: 3)) }
    @MainActor func testShape3() { conform(ShapeTests.self, part: Conformance.Part(3, of: 3)) }
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

    /// Runs `family` - or `part` of it - on AppKit, and holds its verdicts to its file of AppKit's marks. A long
    /// family runs in parts, each a test of its own, so a part can be run alone and the parts side by side.
    @MainActor
    private func conform(_ family: any ConformanceFamily.Type, part: Conformance.Part = .whole) {
        let file = part == .whole ? family.name : "\(family.name)-\(part.number)"
        guard !AppKitExports.skips(family.name, at: "marks/appkit/\(file).txt") else { return }
        let driver = AppKitDriver()
        defer { driver.renderer?.closeForTesting() }
        let verdicts = Conformance.run(
            family, part: part, on: driver, report: { XCTFail($0.message, file: $0.file, line: $0.line) })
        XCTAssertNoThrow(try AppKitExports.hold(
            HostVerdict.text(verdicts, revision: AppKitExports.revision(of: family.name)),
            at: "marks/appkit/\(file).txt"))
    }
}
#endif
