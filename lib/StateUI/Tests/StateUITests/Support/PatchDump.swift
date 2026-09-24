// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The readable rendering of what the core hands a host: a patch, one element
// per line with its fields indented under it and its children deeper, and a
// batch of acts, one per line with its arguments under it. It is what a
// fixture's `.txt` holds and what a review diff reads, and it is read off the
// typed patch a host applies.
//
// A closed vocabulary travels as its member NUMBER, so the dump spells the
// member wherever a property key says which vocabulary the number belongs to:
// `lineBreak: enum tailTruncation(4)`. A number with no key over it - an act's
// argument, a value nested in a list - is printed bare. The spellings come
// from the library's own enums, so the dump can lack a vocabulary
// (`testEveryEnumerationInASidecarIsSpelled` fails on that) but never
// misspell one.

@_spi(Host) @testable import StateUI

enum PatchDump {
    /// A patch and everything under it.
    static func text(_ patch: HostPatch) -> String {
        var out = ""
        write(patch, depth: 0, into: &out)
        return out
    }

    /// A batch of acts, each with its completion when it has one.
    static func text(_ calls: [HostActCall]) -> String {
        var out = ""

        for call in calls {
            out += call.act.name
            if let completion = call.completion {
                out += " completion=\(completion)"
            }
            out += "\n"

            for argument in call.arguments {
                out += "  " + line(for: argument) + "\n"
            }
        }

        return out
    }

    private static func write(_ patch: HostPatch, depth: Int, into out: inout String) {
        let indent = String(repeating: "  ", count: depth)

        var head = indent + patch.type.name + " " + spelled(patch.id)
        if patch.replace { head += " replace" }
        if let recycles = patch.recycles { head += recycles ? " recycles" : " recycles(no)" }
        if let placement = patch.motion { head += moving(placement) }
        // In hex: a reader checks that two rows share a number, not what it is.
        if let shape = patch.shape { head += " shape=\(String(shape, radix: 16))" }
        if case .arranged(let children) = patch.children { head += " arranged(\(children.count))" }
        out += head + "\n"

        for key in patch.properties.keys.sorted() {
            out += indent + "  \(key.name): \(line(for: patch.properties[key]!, under: key.name))\n"
        }

        for key in patch.transitions.keys.sorted() {
            out += indent + "  \(key.name) \(travelling(patch.transitions[key]!.motion))\n"
        }

        if case .replace(let driven)? = patch.driven {
            let all = driven.keys
                .sorted { ($0.name, driven[$0]!.kind.rawValue) < ($1.name, driven[$1]!.kind.rawValue) }
                .map { key in
                    let entry = driven[key]!
                    return "\(key.name)<-\(entry.state) \(entry.mode) \(entry.kind)"
                }

            out += indent + "  driven " + (all.isEmpty ? "none" : all.joined(separator: " ")) + "\n"
        }

        if !patch.clearedProperties.isEmpty {
            out += indent + "  clears \(patch.clearedProperties.map(\.name).joined(separator: " "))\n"
        }

        if case .replace(let events)? = patch.events, !events.isEmpty {
            let all = events.keys.sorted().map { "\($0.name)=\(events[$0]!)" }
            out += indent + "  on \(all.joined(separator: " "))\n"
        }

        switch patch.children {
        case .unchanged:
            break
        case .changed(let children), .arranged(let children):
            for child in children {
                write(child, depth: depth + 1, into: &out)
            }
        }
    }

    private static func spelled(_ id: ElementId) -> String {
        switch id {
        case .auto(let value): String(value)
        case .manual(let value): "\"\(value)\""
        }
    }

    /// How a layout moves its children, said after the element's identity.
    private static func moving(_ placement: HostLayoutMotion) -> String {
        var said = ""
        let lanes = placement.lanes.rawValue

        if lanes != 15 {
            var held: [String] = []

            if lanes & 1 == 0 { held.append("x") }
            if lanes & 2 == 0 { held.append("y") }
            if lanes & 4 == 0 { held.append("width") }
            if lanes & 8 == 0 { held.append("height") }

            said += " holding \(held.joined(separator: "+")) still"
        }

        let motion = placement.motion

        if motion.isInherited {
            return said + " moves as the application does"
        }

        switch motion.law {
        case .spring: return said + " moves on a spring over \(motion.millis)ms"
        case .eased: return said + (motion.millis == 0 ? " moves at once" : " moves over \(motion.millis)ms \(motion.curve)")
        }
    }

    /// How one property travels to the value the line above it states.
    private static func travelling(_ motion: Motion) -> String {
        switch motion.law {
        case .spring: "springs over \(motion.millis)ms, damping \(motion.factor)"
        case .eased: "travels over \(motion.millis)ms \(motion.curve)(\(motion.curve.rawValue))"
        }
    }

    /// One value's line: the leading word is the arm it takes, so a `string`
    /// and a `name` of the same text are told apart. `key` is the property it
    /// was written under, the only thing that can say which vocabulary a
    /// member number belongs to.
    static func line(for value: HostValue, under key: String? = nil) -> String {
        switch value {
        case .bool(let flag):
            return flag ? "true" : "false"
        case .number(let number):
            return "number \(spelled(number))"
        case .string(let text):
            return "string \"\(text)\""
        // `[]` rather than nothing: a line ending in a space is one an editor
        // strips and a fixture check then fails on.
        case .numbers(let numbers):
            guard !numbers.isEmpty else { return "numbers []" }
            return "numbers " + numbers.map(spelled).joined(separator: ",")
        case .strings(let strings):
            guard !strings.isEmpty else { return "strings []" }
            return "strings " + strings.map { "\"\($0)\"" }.joined(separator: ",")
        case .name(let name):
            return "name \"\(name)\""
        case .enumeration(let member):
            guard let spelling = key.flatMap({ spelling(of: member, under: $0) }) else {
                return "enum \(member)"
            }
            return "enum \(spelling)(\(member))"
        case .nothing:
            return "nothing"
        case .color(let red, let green, let blue, let alpha):
            return "color " + [alpha, red, green, blue].map(hex2).joined()
        case .values(let values):
            return "values [" + values.map { line(for: $0) }.joined(separator: ", ") + "]"
        // A node's own value; the differ picks one half before a host sees it.
        case .themed(let light, let dark):
            return "themed [" + line(for: light) + ", " + line(for: dark) + "]"
        }
    }

    // MARK: - What a member number means

    /// The spelling of one member of a closed vocabulary, given the property
    /// key it was written under: `(4, "lineBreak")` is `tailTruncation`. The
    /// keys are `Prop`'s own members, so a renamed property is a compile error
    /// here. Nil for a key not listed or a number the vocabulary lacks, both of
    /// which print the bare number.
    static func spelling(of member: Int32, under key: String) -> String? {
        switch key {
        // The view tiers and the text mixins.
        case Prop.horizontalAlignment.name, Prop.verticalAlignment.name:
            return spelled(member, as: Alignment.self)
        case Prop.horizontalTextAlignment.name, Prop.verticalTextAlignment.name:
            return spelled(member, as: TextAlignment.self)
        case Prop.lineBreak.name:
            return spelled(member, as: LineBreak.self)
        case Prop.textCase.name:
            return spelled(member, as: TextCase.self)
        case Prop.aspect.name:
            return spelled(member, as: Aspect.self)
        case Prop.iconPosition.name:
            return spelled(member, as: IconPosition.self)
        case Prop.type.name:
            return spelled(member, as: PinType.self)
        case Prop.avoidsSafeArea.name:
            return spelled(member, as: SafeArea.self)
        case Prop.layoutDirection.name:
            return spelled(member, as: LayoutDirection.self)
        case Prop.accessibilityHeadingLevel.name:
            return spelled(member, as: HeadingLevel.self)

        // The inputs.
        case Prop.inputPurpose.name:
            return spelled(member, as: InputPurpose.self)
        case Prop.returnKey.name:
            return spelled(member, as: ReturnKey.self)

        // Scrolling, and the pages.
        case Prop.orientation.name:
            return spelled(member, as: ScrollOrientation.self)
        case Prop.horizontalScrollBarVisibility.name, Prop.verticalScrollBarVisibility.name:
            return spelled(member, as: ScrollBarVisibility.self)
        case Prop.placement.name:
            return spelled(member, as: ToolbarItemPlacement.self)

        // The swipe. The side a set of swipe items sits on is internal to the
        // library, so it is spelled here, in SwipeView.swift's order.
        case Prop.mode.name:
            return spelled(member, as: SwipeMode.self)
        case Prop.swipeBehaviorOnInvoked.name:
            return spelled(member, as: SwipeBehaviorOnInvoked.self)
        case Prop.side.name:
            return spelled(member, amongst: ["left", "right", "top", "bottom"])

        // The shapes and the map.
        case Prop.strokeLineCap.name:
            return spelled(member, as: LineCap.self)
        case Prop.strokeLineJoin.name:
            return spelled(member, as: LineJoin.self)
        case Prop.fillRule.name:
            return spelled(member, as: FillRule.self)
        case Prop.indicatorsShape.name:
            return spelled(member, as: IndicatorShape.self)
        case Prop.mapType.name:
            return spelled(member, as: MapType.self)

        // The bit sets: an OptionSet's members are static properties nothing
        // can enumerate, so their names are written out here.
        case Prop.fontAttributes.name:
            return spelled(member, asBitsOf: [
                ("none", FontAttributes.none.rawValue),
                ("bold", FontAttributes.bold.rawValue),
                ("italic", FontAttributes.italic.rawValue),
            ])
        case Prop.textDecorations.name:
            return spelled(member, asBitsOf: [
                ("none", TextDecorations.none.rawValue),
                ("underline", TextDecorations.underline.rawValue),
                ("strikethrough", TextDecorations.strikethrough.rawValue),
            ])
        case Prop.absoluteLayoutProportions.name:
            return spelled(member, asBitsOf: [
                ("none", AbsoluteLayoutProportions.none.rawValue),
                ("x", AbsoluteLayoutProportions.x.rawValue),
                ("y", AbsoluteLayoutProportions.y.rawValue),
                ("width", AbsoluteLayoutProportions.width.rawValue),
                ("height", AbsoluteLayoutProportions.height.rawValue),
                ("position", AbsoluteLayoutProportions.position.rawValue),
                ("size", AbsoluteLayoutProportions.size.rawValue),
                ("all", AbsoluteLayoutProportions.all.rawValue),
            ])
        case Prop.swipeDirection.name:
            return spelled(member, asBitsOf: [
                ("right", SwipeDirection.right.rawValue),
                ("left", SwipeDirection.left.rawValue),
                ("up", SwipeDirection.up.rawValue),
                ("down", SwipeDirection.down.rawValue),
                ("all", SwipeDirection.all.rawValue),
            ])

        default:
            return nil
        }
    }

    /// One member of a vocabulary the library declares, read off its enum.
    static func spelled<Vocabulary: RawRepresentable>(
        _ member: Int32,
        as vocabulary: Vocabulary.Type
    ) -> String? where Vocabulary.RawValue == Int32 {
        Vocabulary(rawValue: member).map { String(describing: $0) }
    }

    /// One member of a vocabulary the library keeps internal - the names in
    /// declaration order, the number being the index.
    static func spelled(_ member: Int32, amongst names: [String]) -> String? {
        names.indices.contains(Int(member)) ? names[Int(member)] : nil
    }

    /// A bit set's bits, named: 3 under `fontAttributes` is `bold|italic`. A
    /// whole-set match comes first, so `all` never reads as its four bits; a
    /// bit no member accounts for answers nil rather than half a spelling.
    private static func spelled(
        _ bits: Int32,
        asBitsOf members: [(name: String, bits: Int32)]
    ) -> String? {
        if let whole = members.first(where: { $0.bits == bits }) { return whole.name }

        var covered: Int32 = 0
        var named: [String] = []

        for member in members where member.bits != 0
            && member.bits & (member.bits - 1) == 0
            && bits & member.bits == member.bits {
            named.append(member.name)
            covered |= member.bits
        }

        guard covered == bits, !named.isEmpty else { return nil }
        return named.joined(separator: "|")
    }

    /// One channel as two uppercase hex digits, so a colour reads the way it
    /// was written, alpha first.
    private static func hex2(_ value: UInt8) -> String {
        let digits = Array("0123456789ABCDEF")
        return String([digits[Int(value >> 4)], digits[Int(value & 0xF)]])
    }

    /// A whole number without its ".0", everything else as Swift spells it.
    static func spelled(_ number: Double) -> String {
        if number.isFinite, number == number.rounded(), abs(number) < 1e15 {
            return String(Int64(number))
        }
        return "\(number)"
    }
}
