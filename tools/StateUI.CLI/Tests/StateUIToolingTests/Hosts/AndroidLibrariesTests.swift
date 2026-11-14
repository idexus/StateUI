// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import XCTest

final class AndroidLibrariesTests: XCTestCase {
    /// The libraries shipped are the product's own and everything it needs, once each, in the order first met - the
    /// platform's own left out, and a library naming itself not followed.
    func testTheLibrariesShippedAreTheProductsClosure() async {
        let graph = [
            "libNotesAndroid.so": ["libStateUI.so", "liblog.so", "libNotesAndroid.so"],
            "libStateUI.so": ["libswiftCore.so", "libc++_shared.so", "libandroid.so"],
            "libswiftCore.so": ["libc++_shared.so", "libm.so"],
            "libc++_shared.so": ["libc.so"],
        ]
        let platform: Set = ["liblog.so", "libandroid.so", "libm.so", "libc.so"]
        let laid = await AndroidLibraries.closure(of: "libNotesAndroid.so", needed: { graph[$0] ?? [] }, isPlatform: platform.contains)
        XCTAssertEqual(laid, ["libNotesAndroid.so", "libStateUI.so", "libswiftCore.so", "libc++_shared.so"])
    }

    /// An ABI's target is the NDK's name of it.
    func testAnABIsTargetIsTheNDKsName() {
        let named = { (abi: String) in
            AndroidLibraries(ndk: URL(fileURLWithPath: "/ndk"), abi: abi, binaries: URL(fileURLWithPath: "/b"), runtime: URL(fileURLWithPath: "/r")).ndkTarget
        }
        XCTAssertEqual(named("arm64-v8a"), "aarch64-linux-android")
        XCTAssertEqual(named("x86_64"), "x86_64-linux-android")
    }
}
