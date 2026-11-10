// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) @testable import StateUITesting
import XCTest

/// Every act a test's window offers it does, on the view the act is for, as that view's user can.
@MainActor
final class UserActTests: XCTestCase {
    /// Each act the window offers, once.
    private static let acts: [UserAct] = [
        .activate, .tap(count: 2), .toggle, .type("Ada"), .submit, .focus, .slide(to: 0.5), .step(up: true),
        .choose("Week"), .pickDate(CalendarDate(year: 2026, month: 11, day: 9)), .pickTime(ClockTime(hour: 10, minute: 30)),
        .pickColor(.blue), .performAccessibilityAction("Archive"), .adjust(.increment),
    ]

    /// The view on `EveryActPage` an act is done to: a switch over every act, so an act the window offers that no
    /// view here takes fails to build.
    private static func view(for act: UserAct) -> String {
        switch act {
        case .activate: "acts.button"
        case .tap, .performAccessibilityAction, .adjust: "acts.mail"
        case .toggle: "acts.switch"
        case .type, .submit, .focus: "acts.field"
        case .slide: "acts.slider"
        case .step: "acts.stepper"
        case .choose: "acts.picker"
        case .pickDate: "acts.date"
        case .pickTime: "acts.time"
        case .pickColor: "acts.color"
        }
    }

    func testEveryActTheWindowOffersItDoes() async throws {
        let window = try await TestWindow(motion: .none) { EveryActPage() }
        let shown = try window.element("acts.shown")

        for act in Self.acts {
            let before = try shown.value(TextElementContract.text)
            try await window.element(Self.view(for: act)).perform(act)
            XCTAssertNotEqual(try shown.value(TextElementContract.text), before, "\(act) changed nothing")
        }
    }

    /// A field bounded past any count of letters takes every word typed into it.
    func testAFieldBoundedPastEveryLengthTakesTheWords() async throws {
        let window = try await TestWindow(motion: .none) { BoundlessPage() }
        let field = try window.element("boundless.field")

        try await field.perform(.type("Ada"))
        XCTAssertEqual(try field.value(TextElementContract.text), "Ada")
    }

    /// A stepper takes a step of its own within its range - to a hundred until told otherwise - and none past an
    /// end, a failure saying why.
    func testAStepperStepsWithinItsRange() async throws {
        let window = try await TestWindow(motion: .none) { StepperPage() }
        let short = try window.element("steps.short")
        let far = try window.element("steps.far")

        try await short.perform(.step(up: true))
        XCTAssertEqual(try short.value(RangeElementContract.value), 5)
        do {
            try await short.perform(.step(up: true))
            XCTFail("a stepper stepped past its range")
        } catch {
            XCTAssertTrue("\(error)".contains("end of its range"), "\(error)")
        }
        try await short.perform(.step(up: false))
        try await far.perform(.step(up: true))

        XCTAssertEqual(try window.element("steps.shown").value(TextElementContract.text), "3.0 2.0")
    }

    /// A picker's choice is found by the words its user sees, not by the value behind them; words it does not offer
    /// are a failure naming them.
    func testAPickerIsChosenByTheWordsItsUserSees() async throws {
        let window = try await TestWindow(motion: .none) { SpanPage() }
        let picker = try window.element("span.picker")

        try await picker.perform(.choose("Week"))

        XCTAssertEqual(try window.element("span.shown").value(TextElementContract.text), "week")
        XCTAssertThrowsError(try picker.performNow(.choose("week"))) { error in
            XCTAssertEqual("\(error)", "the view \"span.picker\" cannot choose: it offers no such choice")
        }
    }

    /// A day, a time and a color are picked as their controls offer them: no day the calendar's range leaves out,
    /// no time a clock does not show, and the opacity kept only where the picker chooses it.
    func testADayATimeAndAColorArePickedAsTheirControlsOfferThem() async throws {
        let window = try await TestWindow(motion: .none) { PickingPage() }
        let day = try window.element("pick.day")
        let time = try window.element("pick.time")

        XCTAssertThrowsError(try day.performNow(.pickDate(CalendarDate(year: 2026, month: 7, day: 1)))) { error in
            XCTAssertTrue("\(error)".contains("no such day"), "\(error)")
        }
        XCTAssertThrowsError(try time.performNow(.pickTime(ClockTime(hour: 25, minute: 0)))) { error in
            XCTAssertTrue("\(error)".contains("no such time"), "\(error)")
        }
        try await day.perform(.pickDate(CalendarDate(year: 2026, month: 6, day: 3)))
        try await time.perform(.pickTime(ClockTime(hour: 7, minute: 15)))
        try await window.element("pick.seeThrough").perform(.pickColor(Color(hex: 0xB22222, opacity: 0.4)))
        try await window.element("pick.opaque").perform(.pickColor(Color(hex: 0xB22222, opacity: 0.4)))

        XCTAssertEqual(try day.value(DatePickerContract.date), CalendarDate(year: 2026, month: 6, day: 3))
        XCTAssertEqual(try time.value(TimePickerContract.time), ClockTime(hour: 7, minute: 15))
        XCTAssertEqual(try window.element("pick.seeThrough").value(ColorPickerContract.color), Color(hex: 0xB22222, opacity: 0.4))
        XCTAssertEqual(try window.element("pick.opaque").value(ColorPickerContract.color), Color(hex: 0xB22222))
    }

    /// The keyboard moved to a view leaves the last: each hears where it now is.
    func testTheFocusMovesFromViewToView() async throws {
        let window = try await TestWindow(motion: .none) { FocusPage() }
        let shown = try window.element("focus.shown")

        try await window.element("focus.first").perform(.focus)
        XCTAssertEqual(try shown.value(TextElementContract.text), "true false")

        try await window.element("focus.second").perform(.focus)
        XCTAssertEqual(try shown.value(TextElementContract.text), "false true")
    }
}

/// A view for every act a test's window does, and one line saying what they did.
private struct EveryActPage: View {
    @State private var heard: [String] = []
    @State private var lit = false
    @State private var name = ""
    @State private var focused = false
    @State private var level = 0.0
    @State private var count = 1.0
    @State private var span = "Day"
    @State private var day = CalendarDate(year: 2026, month: 11, day: 8)
    @State private var time = ClockTime(hour: 9, minute: 0)
    @State private var tint = Color.black

    var body: some View {
        VStack {
            Button("Go").onClicked { heard.append("clicked") }.accessibilityIdentifier("acts.button")
            Text("Mail")
                .onTapped(count: 2) { heard.append("tapped twice") }
                .accessibilityAction("Archive") { heard.append("archived") }
                .onAccessibilityAdjusted { heard.append("adjusted \($0)") }
                .accessibilityIdentifier("acts.mail")
            Switch($lit).accessibilityIdentifier("acts.switch")
            TextField($name).onSubmitted { heard.append("submitted") }.isFocused(into: $focused)
                .accessibilityIdentifier("acts.field")
            Slider($level).accessibilityIdentifier("acts.slider")
            Stepper($count).accessibilityIdentifier("acts.stepper")
            Picker(["Day", "Week"], selection: $span).accessibilityIdentifier("acts.picker")
            DatePicker($day).accessibilityIdentifier("acts.date")
            TimePicker($time).accessibilityIdentifier("acts.time")
            ColorPicker($tint).accessibilityIdentifier("acts.color")
            Text("\(heard) \(lit) \(name) \(focused) \(level) \(count) \(span) \(day) \(time) \(tint)")
                .accessibilityIdentifier("acts.shown")
        }
    }
}

/// A stepper with a step and a range of its own, and one with neither.
private struct StepperPage: View {
    @State private var short = 3.0
    @State private var far = 1.0

    var body: some View {
        VStack {
            Stepper($short).step(2).maximum(5).accessibilityIdentifier("steps.short")
            Stepper($far).accessibilityIdentifier("steps.far")
            Text("\(short) \(far)").accessibilityIdentifier("steps.shown")
        }
    }
}

/// A picker whose values its user sees by words of their own.
private struct SpanPage: View {
    enum Span: String { case day, week }

    @State private var span = Span.day

    var body: some View {
        VStack {
            Picker([Span.day, .week], selection: $span) { $0.rawValue.capitalized }.accessibilityIdentifier("span.picker")
            Text(span.rawValue).accessibilityIdentifier("span.shown")
        }
    }
}

/// A day picker ending in June, a time picker, and a color picker taking opacity beside one that does not.
private struct PickingPage: View {
    @State private var day = CalendarDate(year: 2026, month: 2, day: 10)
    @State private var time = ClockTime(hour: 9, minute: 0)
    @State private var seeThrough = Color(hex: 0x4682B4)
    @State private var opaque = Color(hex: 0x4682B4)

    var body: some View {
        VStack {
            DatePicker($day).maximum(CalendarDate(year: 2026, month: 6, day: 30)).accessibilityIdentifier("pick.day")
            TimePicker($time).accessibilityIdentifier("pick.time")
            ColorPicker($seeThrough).choosesOpacity(true).accessibilityIdentifier("pick.seeThrough")
            ColorPicker($opaque).accessibilityIdentifier("pick.opaque")
        }
    }
}

/// Two fields saying whether each holds the keyboard.
private struct FocusPage: View {
    @State private var first = false
    @State private var second = false

    var body: some View {
        VStack {
            TextField("").isFocused(into: $first).accessibilityIdentifier("focus.first")
            TextField("").isFocused(into: $second).accessibilityIdentifier("focus.second")
            Text("\(first) \(second)").accessibilityIdentifier("focus.shown")
        }
    }
}

/// A field whose bound no count of letters reaches.
private struct BoundlessPage: View {
    @State private var name = ""

    var body: some View {
        VStack { TextField($name).maximumLength(.max).accessibilityIdentifier("boundless.field") }
    }
}
