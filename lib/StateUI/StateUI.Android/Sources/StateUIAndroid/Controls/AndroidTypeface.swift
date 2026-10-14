// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// The typeface words are drawn in, and the size and weight of the platform's type scale for each text style.
/// Design: docs/design/platforms/android/controls.md#a-text-style
@MainActor
enum AndroidTypeface {
    /// A local reference to the typeface of `family` - the platform's where it names none - at `weight`, italic as
    /// `italic` says; nil for the platform's own where neither a family nor a weight is given, whose slant the view's
    /// style bits then give. The caller releases it.
    static func local(family: String?, weight: FontWeight?, italic: Bool) -> jobject? {
        let name = family.flatMap(Java.string)
        defer { Java.release(local: name) }
        guard let weight else {
            return name.flatMap {
                Java.callStaticObject(JavaAPI.typeface, JavaAPI.createTypeface, .object($0), .int(italic ? italicStyle : 0))
            }
        }
        let base = name.flatMap { Java.callStaticObject(JavaAPI.typeface, JavaAPI.createTypeface, .object($0), .int(0)) }
        defer { Java.release(local: base) }
        return Java.callStaticObject(
            JavaAPI.typeface, JavaAPI.createWeightedTypeface, .object(base), .int(Int32(weight.number)), .bool(italic))
    }

    /// `Typeface.ITALIC`.
    static let italicStyle: Int32 = 2
}

extension TextStyle {
    /// The style's size on the platform's Material type scale, in points: Display 1, Headline, Title, Body 2,
    /// Body 1 and Caption.
    var androidSize: Double {
        switch self {
        case .display: 34
        case .title: 24
        case .subtitle: 20
        case .headline, .body: 14
        case .caption: 12
        }
    }

    /// The style's weight on the platform's Material type scale: a title's and an emphasized body's medium.
    var androidWeight: FontWeight {
        switch self {
        case .subtitle, .headline: .medium
        case .display, .title, .body, .caption: .regular
        }
    }
}
