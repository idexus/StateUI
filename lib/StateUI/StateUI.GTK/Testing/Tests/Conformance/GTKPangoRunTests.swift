// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@testable import StateUIGTKDriver
import XCTest

/// The driver reads a label's look from Pango's copy of its attributes, and lets go of every copy it was handed.
final class GTKPangoRunTests: XCTestCase {
    /// Attributes of a class of the test's own count themselves as Pango copies and destroys them: reading a run
    /// many times leaves the list's own and no copy, and the list freed leaves none.
    func testAReadLetsGoOfEveryCopyItWasHanded() {
        let list = pango_attr_list_new()
        for start in [UInt32(0), 4] {
            let attribute = Counted.make()
            attribute.pointee.start_index = start
            attribute.pointee.end_index = start + 4
            pango_attr_list_insert(list, attribute)
        }
        XCTAssertEqual(Counted.live, 2)

        for _ in 0..<5 { _ = PangoRun(list, at: 1).holds(.fontSize) }
        XCTAssertEqual(Counted.live, 2, "the list's own two, no copy left by the reads")

        pango_attr_list_unref(list)
        XCTAssertEqual(Counted.live, 0)
    }
}

/// A Pango attribute class whose instances count themselves alive.
private enum Counted {
    nonisolated(unsafe) static var live = 0

    nonisolated(unsafe) static let type = pango_attr_type_register("stateui-counted")

    nonisolated(unsafe) static let klass: UnsafeMutablePointer<PangoAttrClass> = {
        let klass = UnsafeMutablePointer<PangoAttrClass>.allocate(capacity: 1)
        klass.initialize(to: PangoAttrClass(
            type: type,
            copy: { original in
                let copy = Counted.make()
                copy.pointee.start_index = original?.pointee.start_index ?? 0
                copy.pointee.end_index = original?.pointee.end_index ?? 0
                return copy
            },
            destroy: { attribute in
                Counted.live -= 1
                attribute?.deallocate()
            },
            equal: { _, _ in 0 }))
        return klass
    }()

    /// A new counted attribute.
    static func make() -> UnsafeMutablePointer<PangoAttribute> {
        let attribute = UnsafeMutablePointer<PangoAttribute>.allocate(capacity: 1)
        pango_attribute_init(attribute, klass)
        live += 1
        return attribute
    }
}
