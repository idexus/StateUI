// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Versions as tools print them: compared part by part, and read out of what Swift says.
public enum Versions {
    /// Below 0, 0 or above 0 as `a` is older than, the same as or newer than `b`, part by part: `6.4.1` > `6.4`.
    public static func compare(_ a: String, _ b: String) -> Int {
        let (first, second) = (parts(a), parts(b))
        for index in 0..<max(first.count, second.count) {
            let difference = (index < first.count ? first[index] : 0) - (index < second.count ? second[index] : 0)
            if difference != 0 { return difference }
        }
        return 0
    }

    /// Whether `version` is `minimum` or newer.
    public static func atLeast(_ version: String, _ minimum: String) -> Bool { compare(version, minimum) >= 0 }

    /// The first version - digits and dots - in `text`.
    public static func first(in text: String) -> String? {
        text.firstMatch(of: /\d+(\.\d+)+|\d+/).map { String($0.output.0) }
    }

    /// The release `swift --version` names - `6.4`, or `6.4.1` - read from `Swift version` or the first version.
    public static func swiftRelease(in text: String) -> String? {
        let version = text.firstMatch(of: /Swift version (\d+\.\d+(?:\.\d+)?)/).map { String($0.output.1) }
            ?? text.firstMatch(of: /\d+\.\d+(?:\.\d+)?/).map { String($0.output) }
        guard let version else { return nil }
        return version.hasSuffix(".0") && version.split(separator: ".").count == 3 ? String(version.dropLast(2)) : version
    }

    /// Whether a swift.org toolchain wrote `swift --version`'s output: its build `swift-6.4-RELEASE`.
    public static func isSwiftOrgBuild(_ text: String) -> Bool { text.contains(/\(swift-\d/) }

    /// The last Swift SDK of `release` whose id ends in `_<family>` among the ids `swift sdk list` printed; `wasm`
    /// is `swift-6.4.2-RELEASE_wasm`, never its `_wasm-embedded` sibling.
    public static func swiftSDK(of release: String?, in list: String, family: String) -> String? {
        guard let release else { return nil }
        return list.split(whereSeparator: \.isWhitespace).map(String.init)
            .filter { $0.lowercased().hasSuffix("_" + family) && swiftRelease(in: $0) == release }.last
    }

    private static func parts(_ version: String) -> [Int] {
        version.split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
    }
}
