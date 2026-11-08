// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What a test's window does on a host, walked through the host's own driver: a click counted, words typed and a
/// switch turned reaching their states, a view found by its aim - so an application's test reads alike on every
/// host and with no toolkit.
/// Design: docs/design/host/testing.md#the-same-test-on-every-host
@_spi(Host) @MainActor public enum TestWindowWalk {
    /// What went otherwise than the walk expects on the host `driver` drives; none where everything held.
    public static func failures(on driver: any HostDriver) -> [String] {
        var failures: [String] = []
        func expect<Value: Equatable>(_ held: Value?, _ wanted: Value, _ what: String) {
            if held != wanted { failures.append("\(what): \(wanted) expected, \(held.map { "\($0)" } ?? "none") held") }
        }
        do {
            let counter = TestWindow(driver: driver, motion: .none) { CounterPage() }
            let button = try counter.element("counter.add")
            try button.performNow(.activate)
            try button.performNow(.activate)
            expect(try button.value(TextElementContract.text), "Clicked 2 times", "a click counted")

            let form = TestWindow(driver: driver, motion: .none) { FormPage() }
            try form.element("form.name").performNow(.type("Ada"))
            try form.element("form.lamp").performNow(.toggle)
            expect(try form.element("form.greeting").value(TextElementContract.text), "Hello, Ada - lit",
                   "words typed and a switch turned")

            let page = AimedPage()
            var disappeared = false
            var destroyed = 0
            let aimed = TestWindow(driver: driver, motion: .none) {
                page.onDisappearing { disappeared = true }.onDestroying { destroyed += 1 }
            }
            let field = try aimed.element(page.name)
            try field.performNow(.type("Grace"))
            expect(try field.value(TextElementContract.text), "Grace", "a view found by its aim")

            try aimed.closeNow()
            try aimed.closeNow()
            expect(disappeared, true, "the page heard its window closed")
            expect(destroyed, 1, "the page was destroyed once")
            if (try? field.value(TextElementContract.text)) != nil { failures.append("a closed window still held a view") }
        } catch {
            failures.append("\(error)")
        }
        return failures
    }
}

/// A button counting its clicks.
struct CounterPage: View {
    @State private var clicks = 0

    var body: some View {
        Button("Clicked \(clicks) time\(clicks == 1 ? "" : "s")")
            .accessibilityIdentifier("counter.add")
            .onClicked { clicks += 1 }
    }
}

/// A field, a switch, and the greeting both make - and two views of one identifier.
struct FormPage: View {
    @State private var name = ""
    @State private var lit = false

    var body: some View {
        VStack {
            TextField($name).accessibilityIdentifier("form.name")
            Switch($lit).accessibilityIdentifier("form.lamp")
            Text("Hello, \(name) - \(lit ? "lit" : "dark")").accessibilityIdentifier("form.greeting")
            Text("One").accessibilityIdentifier("form.twice")
            Text("Two").accessibilityIdentifier("form.twice")
        }
    }
}

/// A field the page aims at.
struct AimedPage: View {
    @Aim(TextField.self) var name
    @State private var words = ""

    var body: some View {
        TextField($words).aim(name)
    }
}
