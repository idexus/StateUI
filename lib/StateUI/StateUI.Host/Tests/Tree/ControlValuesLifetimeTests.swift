// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

@MainActor
final class ControlValuesLifetimeTests: XCTestCase {
    private final class Control {}

    func testSavedValuesReadTheLiveElementWithoutOwningIt() throws {
        let runtime = HostRuntime.still()
        let registry = Registry<Control>()
        var saved: ControlValues<TextContract>?
        registry.add(TextContract.self, create: { _ in Control() }) { control in
            control.applies(TextualElementContract.text) { _, values in saved = ControlValues(values) }
        }
        var text = HostPatch(id: .manual("text"), type: TextContract.nodeType)
        text.properties[TextualElementContract.text.token] = .string("First")
        runtime.tree.apply(text, complete: true)
        weak let released = runtime.tree.root
        do {
            let element = try XCTUnwrap(runtime.tree.root)
            registry.apply([TextualElementContract.text.token], to: Control(), presenting: element)
        }
        XCTAssertEqual(saved?[TextualElementContract.text], "First")

        text.properties[TextualElementContract.text.token] = .string("Second")
        runtime.tree.apply(text, complete: false)
        XCTAssertEqual(saved?[TextualElementContract.text], "Second")

        runtime.tree.apply(HostPatch(id: .manual("replacement"), type: SpaceContract.nodeType), complete: true)
        XCTAssertNil(released, "values handed to a control must not retain a removed element")
        XCTAssertNil(saved?[TextualElementContract.text])
        XCTAssertEqual(saved?.changed(TextualElementContract.text), true)
    }
}
