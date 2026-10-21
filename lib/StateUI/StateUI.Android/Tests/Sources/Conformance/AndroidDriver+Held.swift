// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Android
import CStateUIAndroid
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
@_spi(Host) import StateUIConformance

/// What the Android driver reads of a member's value: from the view Android holds - a control's state, a view's
/// transform, its node's words as TalkBack reads them - never from what the host last wrote.
/// Design: docs/design/platforms/android/conformance.md#what-the-driver-reads
extension AndroidDriver {
    func held(_ property: Prop, on element: MountedElement) throws -> HostValue? {
        if element.type == .menuItem || element.type == .toolbarItem { return try itemHolds(property, element) }
        if [.barSubtitle, .barBackgroundColor, .barForegroundColor].contains(property) {
            return Self.barHolds(property, of: element)
        }
        if element.type == .page, [.showsBackButton, .showsNavigationBar, .showsTitle].contains(property) {
            return Self.pageBarHolds(property, of: element)
        }
        if property == .title || property == .icon, let tabs = element.parent, tabs.type == .tabView {
            return try tabHolds(property, of: element, in: tabs)
        }
        if element.type == .window, property == .title { return Self.activityTitle() }
        if element.type == .window, property == .background { return Self.windowBackground() }
        if element.type == .textSpan { return try spanHolds(property, on: element) }
        let view = (element.native as? AndroidElement)?.view
        if let field = view as? AndroidDateFieldView, let held = try Self.dateFieldHolds(property, field) { return held }
        if let web = view as? AndroidWebView, let held = try Self.webHolds(property, web) { return held }
        switch (property, view) {
        case (.isOn, let toggle as AndroidToggleView): return toggle.isOn.propValue
        case (.isShown, let popover as AndroidPopoverView): return popover.windowShows.propValue
        case (.role, let button as AndroidButtonView): return button.role.map(\.propValue) ?? HostValue.nothing
        case (.showsMenuArrow, let button as AndroidButtonView):
            return Java.callStaticBool(Self.testMenus, Self.showsMenuArrow, .object(button.reference)).propValue
        case (.value, let slider as AndroidSliderView): return slider.value.propValue
        case (.minimum, let slider as AndroidSliderView): return slider.minimum.propValue
        case (.maximum, let slider as AndroidSliderView): return slider.maximum.propValue
        case (.value, let stepper as AndroidStepperView): return stepper.value.propValue
        case (.minimum, is AndroidStepperView), (.maximum, is AndroidStepperView), (.step, is AndroidStepperView):
            throw DriverCannot(
                "read a stepper's range", because: "Android's stepper is two buttons, which hold none: an end turns one off")
        case (.isRefreshEnabled, let pulled as any AndroidRefreshing):
            return (pulled.refresh.map { Java.callBool($0.layout.reference, JavaAPI.isEnabled) } ?? false).propValue
        case (.isRefreshing, let pulled as any AndroidRefreshing):
            return (pulled.refresh.map { Java.callBool($0.layout.reference, JavaAPI.isRefreshing) } ?? false).propValue
        case (.scrollOffset, let scroll as AndroidScrollView):
            var offset = Point(x: 0, y: 0)
            for (scroller, across) in zip(scroll.scrollers, Self.ways(of: scroll)) {
                if across { offset.x = Double(Java.callInt(scroller.reference, JavaAPI.getScrollX)) / 2 }
                else { offset.y = Double(Java.callInt(scroller.reference, JavaAPI.getScrollY)) / 2 }
            }
            return offset.propValue
        case (.selectedTab, let tabs as AndroidTabView): return Self.selectedTab(of: tabs)?.propValue
        case (.progress, let bar as AndroidProgressBarView): return bar.progress.propValue
        case (.showsSidebar, let split as AndroidSplitView): return split.isPresented.propValue
        case (.sidebarOverlays, let split as AndroidSplitView): return split.overlays.propValue
        case (.sidebarBackground, let split as AndroidSplitView):
            return split.grounds.beside.map { Self.material(argb: Int64(UInt32(bitPattern: $0))) }
        case (.flyoutBackground, let split as AndroidSplitView):
            guard split.overlays, let drawer = split.heldViews().last else {
                throw DriverCannot("read the drawer's surface", because: "the sidebar stands beside the detail")
            }
            let argb = Java.callStaticLong(JavaAPI.views, Self.sidebarColor, .object(drawer.reference))
            return argb == Int64.min ? nil : Self.material(argb: argb)
        case (.selectedItems, let items as AndroidItemsView): return .strings(items.selectedForTesting)
        case (.selectionMode, let items as AndroidItemsView):
            // As the list's node tells TalkBack: Android's collection numbers its modes as StateUI does.
            return TestAccessibility.selectionMode(of: items).flatMap(SelectionMode.init(rawValue:))?.propValue
        case (.isAnimating, let spinner as AndroidActivityIndicatorView):
            // A spinner that runs is visible; one that stopped is invisible, and the host keeps no other trace.
            return (Java.callInt(spinner.reference, JavaAPI.getVisibility) == 0).propValue
        case (.text, let text as AndroidTextualView): return text.text.propValue
        // The return key as the field asks the keyboard for it: EditorInfo's actions, as the host writes them.
        case (.submitLabel, let field as AndroidTextFieldView):
            let action = Java.callInt(field.reference, Self.getImeOptions) & 0xff
            let key: SubmitLabel = switch action {
            case 2: .go
            case 3: .search
            case 4: .send
            case 5: .next
            case 6: .done
            default: .default
            }
            return key.propValue
        // Read only: the field offers a keyboard nothing to edit.
        case (.isReadOnly, let field as AndroidTextFieldView):
            return (!Java.callBool(field.reference, Self.onCheckIsTextEditor)).propValue
        case (.isSelectable, let text as AndroidTextView): return text.isSelectable.propValue
        case (.fontSize, let text as AndroidTextualView):
            return Double(Java.callStaticFloat(Self.testText, Self.points, .object(text.reference))).rounded().propValue
        case (.isFontAutoScalingEnabled, let text as AndroidTextualView):
            return try Self.scales(Java.callStaticInt(Self.testText, Self.scales, .object(text.reference)))
        case (.fontAttributes, let text as AndroidTextualView):
            return FontAttributes(rawValue: Java.callStaticInt(Self.testText, Self.style, .object(text.reference)) & 2)
                .propValue
        case (.fontWeight, let text as AndroidTextualView):
            return FontWeight(nearest: Double(Java.callStaticInt(Self.testText, Self.weight, .object(text.reference))))
                .propValue
        case (.textColor, let text as AndroidTextualView):
            return Self.color(UInt32(bitPattern: Java.callInt(text.reference, Self.getCurrentTextColor))).propValue
        case (.background, let view?):
            let held = Java.callStaticLong(Self.testPixels, Self.background, .object(view.reference))
            guard held >> 32 == 1 else { throw DriverCannot("read a background of no one color") }
            return StandIns.material(painted: Self.color(UInt32(truncatingIfNeeded: held))).propValue
        case (.fontSize, let picker as AndroidPickerView), (.fontAttributes, let picker as AndroidPickerView),
             (.fontWeight, let picker as AndroidPickerView),
             (.isFontAutoScalingEnabled, let picker as AndroidPickerView),
             (.textColor, let picker as AndroidPickerView), (.horizontalTextAlignment, let picker as AndroidPickerView):
            return try Self.fieldHolds(property, of: picker)
        case (.fontFamily, is AndroidPickerView):
            throw DriverCannot("read a family", because: "Android's typeface keeps no family's name")
        case (.options, let picker as AndroidPickerView) where picker.presentation != .menu:
            return Java.frame {
                guard let words = Java.callStaticObject(Self.testPicker, Self.radios, .object(picker.reference)) else {
                    return [String]()
                }
                return (0..<Java.jni.GetArrayLength(Java.env, words)).map { index in
                    Java.jni.GetObjectArrayElement(Java.env, words, index).map { Java.text($0) } ?? ""
                }
            }.propValue
        case (.selectedIndex, let picker as AndroidPickerView) where picker.presentation != .menu:
            return Int(Java.callStaticInt(Self.testPicker, Self.checkedRadio, .object(picker.reference))).propValue
        case (.options, let picker as AndroidPickerView): return Array(Self.rows(of: picker).dropFirst()).propValue
        case (.placeholder, let picker as AndroidPickerView): return Self.rows(of: picker).first?.propValue
        case (.selectedIndex, let picker as AndroidPickerView):
            // The title's row stands first: it is no choice.
            return (Int(Java.callInt(picker.reference, Self.getSelectedItemPosition)) - 1).propValue
        case (.fontFamily, _ as AndroidTextualView):
            throw DriverCannot("read a family", because: "Android's typeface keeps no family's name")
        case (_, let view?):
            if let held = try Self.viewHolds(property, view) { return held }
            throw DriverCannot(reading: property, of: element)
        default: throw DriverCannot(reading: property, of: element)
        }
    }

    /// The look of the words a picker's closed field shows: the row the spinner shows as chosen.
    private static func fieldHolds(_ property: Prop, of picker: AndroidPickerView) throws -> HostValue? {
        let held: HostValue?? = Java.frame {
            guard let row = Java.callObject(picker.reference, getSelectedView) else { return .none }
            switch property {
            case .fontSize: return Double(Java.callStaticFloat(testText, points, .object(row))).rounded().propValue
            case .isFontAutoScalingEnabled:
                return try? Self.scales(Java.callStaticInt(testText, scales, .object(row)))
            case .fontAttributes:
                return FontAttributes(rawValue: Java.callStaticInt(testText, style, .object(row)) & 2).propValue
            case .fontWeight:
                return FontWeight(nearest: Double(Java.callStaticInt(testText, weight, .object(row)))).propValue
            case .textColor: return color(UInt32(bitPattern: Java.callInt(row, getCurrentTextColor))).propValue
            default:
                // Gravity's horizontal bits: center 1, start or left 3, end or right 5.
                guard let gravity = read(row, "gravity").flatMap(Int.init) else { return .some(nil) }
                return (gravity & 7 == 1 ? TextAlignment.center : gravity & 7 == 5 ? .end : .start).propValue
            }
        }
        guard let held else { throw DriverCannot("read the field of a Picker showing no row") }
        return held
    }

    /// What every view holds: whether it shows, how opaque it is, whether it takes input, how it is moved, and what
    /// assistive technology meets - its node's words, as TalkBack reads them.
    private static func viewHolds(_ property: Prop, _ view: AndroidView) throws -> HostValue? {
        let reference = view.reference
        let float = { (method: jmethodID) in Double(Java.callFloat(reference, method)) }
        switch property {
        // Shown: attached to a window, and neither it nor any view it stands in hidden.
        case .isVisible: return Java.callBool(reference, isShown).propValue
        case .opacity: return float(getAlpha).propValue
        case .isEnabled: return Java.callBool(reference, isEnabled).propValue
        // The direction Android resolved for the view: LAYOUT_DIRECTION_RTL is 1.
        case .layoutDirection:
            return (Java.callInt(reference, getLayoutDirection) == 1 ? LayoutDirection.rightToLeft : .leftToRight).propValue
        case .translationX: return (float(getTranslationX) / 2).propValue
        case .translationY: return (float(getTranslationY) / 2).propValue
        case .rotation: return float(getRotation).propValue
        case .rotationX: return float(getRotationX).propValue
        case .rotationY: return float(getRotationY).propValue
        case .scaleX: return float(getScaleX).propValue
        case .scaleY: return float(getScaleY).propValue
        case .scale:
            let (across, down) = (float(getScaleX), float(getScaleY))
            return (across == down ? across : 1).propValue
        case .pivotX:
            // A share of the view's size, which Android keeps in pixels.
            let width = Double(view.frame.width)
            return (width > 0 ? float(getPivotX) / width : 0.5).propValue
        case .pivotY:
            let height = Double(view.frame.height)
            return (height > 0 ? float(getPivotY) / height : 0.5).propValue
        case .accessibilityLabel: return TestAccessibility.word("label", of: view).propValue
        case .accessibilityHint: return TestAccessibility.word("hint", of: view).propValue
        case .accessibilityIdentifier: return TestAccessibility.word("id", of: view).propValue
        case .accessibilityRole:
            let kind = TestAccessibility.word("kind", of: view)
            return AccessibilityRole.allCases.first { AndroidView.accessibilityClass($0) == kind }?.propValue
        case .accessibilityValue: return TestAccessibility.word("value", of: view).propValue
        case .isAccessibilityHidden:
            let presence = Java.callInt(reference, JavaAPI.getImportantForAccessibility)
            return (presence == 2 || presence == 4).propValue
        case .hidesChildrenFromAccessibility:
            return (Java.callInt(reference, JavaAPI.getImportantForAccessibility) == 4).propValue
        case .accessibilityHeading:
            throw DriverCannot("read a heading's level", because: "Android marks a heading, not its level")
        case .tooltip:
            return Java.frame {
                Java.callObject(reference, JavaAPI.getTooltipText).flatMap { Java.callObject($0, JavaAPI.toString) }
                    .map { Java.text($0) }
            }.propValue
        default: return controlHolds(property, view)
        }
    }


    /// The activity's title, as the system's recent tasks show it.
    /// The plain color the activity's window shows behind its pages; nil where it shows none.
    static func windowBackground() -> HostValue? {
        let argb = Java.callStaticLong(JavaAPI.environment, readWindowBackground, .object(TestContext.window.reference))
        guard argb != Int64.min else { return nil }
        let packed = UInt32(truncatingIfNeeded: argb)
        return StandIns.material(painted: Color(
            red: Int(packed >> 16 & 255), green: Int(packed >> 8 & 255), blue: Int(packed & 255),
            alpha: Int(packed >> 24 & 255))).propValue
    }

    /// The color `argb` as a material.
    static func material(argb: Int64) -> HostValue {
        let packed = UInt32(truncatingIfNeeded: argb)
        return Material.color(Color(
            red: Int(packed >> 16 & 255), green: Int(packed >> 8 & 255), blue: Int(packed & 255),
            alpha: Int(packed >> 24 & 255))).propValue
    }

    static let sidebarColor = Java.staticMethod(JavaAPI.views, "sidebarColor", "(Landroid/view/View;)J")

    static let readWindowBackground = Java.staticMethod(
        JavaAPI.environment, "windowBackground", "(Landroid/app/Activity;)J")
    static let night = Java.staticMethod(JavaAPI.environment, "night", "(Landroid/content/Context;)Z")

    static func activityTitle() -> HostValue? {
        Java.frame {
            Java.callObject(TestContext.window.reference, getTitle).flatMap { Java.callObject($0, JavaAPI.toString) }
                .map { .string(Java.text($0)) }
        }
    }

    static let getSelectedView = Java.method(
        Java.findClass("android/widget/AdapterView"), "getSelectedView", "()Landroid/view/View;")
    static let getTitle = Java.method(Java.findClass("android/app/Activity"), "getTitle", "()Ljava/lang/CharSequence;")
    static let isShown = Java.method(JavaAPI.view, "isShown", "()Z")
    static let getLayoutDirection = Java.method(JavaAPI.view, "getLayoutDirection", "()I")
    static let onCheckIsTextEditor = Java.method(JavaAPI.view, "onCheckIsTextEditor", "()Z")
    static let getImeOptions = Java.method(JavaAPI.textView, "getImeOptions", "()I")
    static let getTranslationX = Java.method(JavaAPI.view, "getTranslationX", "()F")
    static let getTranslationY = Java.method(JavaAPI.view, "getTranslationY", "()F")
    static let getRotation = Java.method(JavaAPI.view, "getRotation", "()F")
    static let getRotationX = Java.method(JavaAPI.view, "getRotationX", "()F")
    static let getRotationY = Java.method(JavaAPI.view, "getRotationY", "()F")
    static let getScaleX = Java.method(JavaAPI.view, "getScaleX", "()F")
    static let getScaleY = Java.method(JavaAPI.view, "getScaleY", "()F")
    static let getPivotX = Java.method(JavaAPI.view, "getPivotX", "()F")
    static let getPivotY = Java.method(JavaAPI.view, "getPivotY", "()F")
    static let testText = Java.findClass("stateui/android/test/TestText")
    static let points = Java.staticMethod(testText, "points", "(Landroid/widget/TextView;)F")
    static let style = Java.staticMethod(testText, "style", "(Landroid/widget/TextView;)I")
    static let weight = Java.staticMethod(testText, "weight", "(Landroid/widget/TextView;)I")
    static let scales = Java.staticMethod(testText, "scales", "(Landroid/widget/TextView;)I")
    static let primaryWords = Java.staticMethod(testText, "primaryWords", "(Landroid/content/Context;)I")

    /// Whether a size follows the user's font scale, as the test reads it: 1, 0, or -1 where Android cannot say.
    static func scales(_ held: Int32) throws -> HostValue? {
        guard held >= 0 else { throw DriverCannot("read a size's unit", because: "Android says it from API 30") }
        return (held == 1).propValue
    }
    static let getCurrentTextColor = Java.method(JavaAPI.textView, "getCurrentTextColor", "()I")

    /// A picker's rows' words as its spinner shows them, the title's first.
    private static func rows(of picker: AndroidPickerView) -> [String] {
        Java.frame {
            guard let rows = Java.callStaticObject(testPicker, pickerRows, .object(picker.reference)) else { return [] }
            return (0..<Java.jni.GetArrayLength(Java.env, rows)).map { index in
                Java.jni.GetObjectArrayElement(Java.env, rows, index).map { Java.text($0) } ?? ""
            }
        }
    }

    /// A color Android holds as 0xAARRGGBB.
    static func color(_ argb: UInt32) -> Color {
        Color(red: Int(argb >> 16 & 0xFF), green: Int(argb >> 8 & 0xFF), blue: Int(argb & 0xFF), alpha: Int(argb >> 24))
    }

    static let testPixels = Java.findClass("stateui/android/test/TestPixels")
    static let background = Java.staticMethod(testPixels, "background", "(Landroid/view/View;)J")
    static let pixels = Java.staticMethod(testPixels, "colors", "(Landroid/view/View;[I)[I")
    static let paintNothing = Java.staticMethod(testPixels, "paintNothing", "(Landroid/app/Activity;)V")

    /// Forgets every value the host keeps, before a case writes its own.
    func forgetWhatIsKept() {
        Java.callStatic(Self.testStore, Self.forget, .object(TestContext.window.reference))
    }

    static let testStore = Java.findClass("stateui/android/test/TestStore")
    static let forget = Java.staticMethod(testStore, "forget", "(Landroid/content/Context;)V")

    /// The words the host keeps under `key` for the next launch: a value of the application's from the
    /// preferences, one of the first scene's from the scenes kept beside them.
    func kept(_ key: String, inScene: Bool) throws -> String? {
        let context = TestContext.window.reference
        if inScene { return AndroidPersistence.readScenes(context: context).scenes.first?.values[key]?.string }
        return AndroidPersistence.word(key, context: context)
    }
}
