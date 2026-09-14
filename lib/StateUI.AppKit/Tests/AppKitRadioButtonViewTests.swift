// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

final class AppKitRadioButtonViewTests: XCTestCase {
    @MainActor
    func testNativeRadioSeparatesProgramAndReaderSelection() {
        let radio = AppKitRadioButtonView()
        var selections = 0
        radio.onSelected = { selections += 1 }

        radio.apply(
            checked: true,
            text: "Medium",
            font: .systemFont(ofSize: 14),
            textColor: .systemPurple,
            enabled: false)
        XCTAssertEqual(radio.state, .on)
        XCTAssertEqual(radio.title, "Medium")
        XCTAssertFalse(radio.isEnabled)
        XCTAssertEqual(selections, 0)

        radio.apply(
            checked: false,
            text: "Medium",
            font: .systemFont(ofSize: 14),
            textColor: .labelColor,
            enabled: true)
        radio.selectForTesting()

        XCTAssertEqual(radio.state, .on)
        XCTAssertEqual(selections, 1)
    }

    @MainActor
    func testNamedGroupReportsOldFalseBeforeNewTrueAcrossContainers() {
        var reports: [(Int32, [HostValue])] = []
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { reports.append(($0, $1)) })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(applicationWithNamedRadios())
        let second = renderer.viewForTesting(id: .manual("large")) as? AppKitRadioButtonView
        second?.selectForTesting()

        XCTAssertEqual(reports.map(\.0), [11, 12])
        XCTAssertEqual(reports.map { $0.1.first?.bool }, [false, true])
    }

    private func applicationWithNamedRadios() -> HostPatch {
        var first = HostPatch(id: .manual("medium"), type: .radioButton)
        first.properties = [
            .text: .string("Medium"),
            .groupName: .name("size"),
            .isChecked: .bool(true),
        ]
        first.events = .replace([.checkedChanged: 11])

        var second = HostPatch(id: .manual("large"), type: .radioButton)
        second.properties = [
            .text: .string("Large"),
            .groupName: .name("size"),
            .isChecked: .bool(false),
        ]
        second.events = .replace([.checkedChanged: 12])

        var firstContainer = HostPatch(id: .manual("first-container"), type: .vStack)
        firstContainer.children = .arranged([first])
        var secondContainer = HostPatch(id: .manual("second-container"), type: .vStack)
        secondContainer.children = .arranged([second])

        var content = HostPatch(id: .manual("content"), type: .vStack)
        content.children = .arranged([firstContainer, secondContainer])
        var page = HostPatch(id: .manual("page"), type: .page)
        page.children = .arranged([content])
        var window = HostPatch(id: .manual("window"), type: .window)
        window.children = .arranged([page])
        var scene = HostPatch(id: .manual("scene"), type: .scene)
        scene.children = .arranged([window])
        var application = HostPatch(id: .manual("application"), type: .application)
        application.children = .arranged([scene])
        return application
    }
}

#endif
