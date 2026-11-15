// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUIToolingProtocol

extension Doctor {
    /// What AppKit, UIKit and Android need on macOS.
    func macChecks() -> [Check] {
        let floor = Self.appleFloor
        let android = AndroidTools()
        return [
            Check(
                component: "macOS \(floor) or newer", neededBy: "AppKit", hosts: [.appkit],
                advice: "Update macOS to \(floor) or newer.") {
                    let version = await ToolOutput.text(.name("sw_vers"), ["-productVersion"])
                    return Self.served(version?.trimmingCharacters(in: .whitespacesAndNewlines), floor)
                },
            Check(
                component: "Xcode 27 or newer", neededBy: "AppKit, UIKit", hosts: [.appkit, .uikit],
                advice: "Install Xcode 27 from the App Store, then run it once, or `xcode-select -s` it.") {
                    let text = await ToolOutput.text(.name("xcodebuild"), ["-version"]) ?? ""
                    return Self.served(ToolText.xcodeVersion(in: text), "27")
                },
            Check(
                component: "an iOS \(floor) or newer simulator runtime", neededBy: "UIKit", hosts: [.uikit],
                advice: "Install the iOS platform in Xcode's Settings, Components.") {
                    let json = await ToolOutput.text(.name("xcrun"), ["simctl", "list", "runtimes", "available", "-j"]) ?? ""
                    return Self.served(ToolText.newestIOSRuntime(in: json), floor)
                },
            Check(
                component: "an Apple Development certificate", neededBy: "UIKit on an iPhone or iPad", hosts: [],
                advice: "Sign in with your Apple Account in Xcode's Settings, Accounts, and make a development certificate"
                    + " there; Xcode makes a device's profile the first time it runs an application on it.") {
                    let text = await ToolOutput.text(.name("security"), ["find-identity", "-v", "-p", "codesigning"]) ?? ""
                    return Self.present(ToolText.developmentIdentity(in: text))
                },
            Check(
                component: "Swift 6.4 from swift.org, with the Swift SDK for Android of the same release",
                neededBy: "Android", hosts: [.android],
                advice: "Install the swift.org toolchain and its SDK: "
                    + "https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html") {
                    let found = await android.swift()
                    return Self.present(found.map { "\($0.sdk) (\($0.compiler.path))" })
                },
            Check(
                component: "the Android SDK with platform 36 and its build tools", neededBy: "Android", hosts: [.android],
                advice: "Install it with Android Studio's SDK Manager, and set ANDROID_HOME where it is not"
                    + " ~/Library/Android/sdk.") {
                    let (sdk, files) = (android.sdk, FileManager.default)
                    let tools = sdk.appendingPathComponent("build-tools")
                    let aapt2 = ((try? files.contentsOfDirectory(atPath: tools.path)) ?? [])
                        .contains { files.fileExists(atPath: tools.appendingPathComponent($0).appendingPathComponent("aapt2").path) }
                    let platform = files.fileExists(atPath: sdk.appendingPathComponent("platforms/android-36").path)
                    let platformTools = files.fileExists(atPath: sdk.appendingPathComponent("platform-tools").path)
                    return Self.present(aapt2 && platform && platformTools ? sdk.path : nil)
                },
            Check(
                component: "the Android NDK r30 or newer", neededBy: "Android", hosts: [.android],
                advice: "Install it with Android Studio's SDK Manager, or name one with ANDROID_NDK_HOME.") {
                    guard let ndk = android.ndk(for: await android.swift()?.sdk) else { return .missing }
                    let properties = try? String(contentsOf: ndk.appendingPathComponent("source.properties"), encoding: .utf8)
                    return Self.served(properties.flatMap { ToolText.ndkRevision(in: $0) }, "30", at: ndk.path)
                },
            Check(
                component: "JDK 21", neededBy: "Android, for Gradle", hosts: [.android],
                advice: "Install a JDK 21 - Android Studio's, or one of your own named by JAVA_HOME.") {
                    let home = await ToolOutput.text(.path("/usr/libexec/java_home"), ["-v", "21"])?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if let home, !home.contains("Unable") { return .found(home) }
                    guard let own = ProcessInfo.processInfo.environment["JAVA_HOME"], !own.isEmpty else { return .missing }
                    let version = await ToolOutput.text(.path(own + "/bin/java"), ["-version"]) ?? ""
                    return Self.present(version.contains("\"21.") ? own : nil)
                },
        ]
    }
}
