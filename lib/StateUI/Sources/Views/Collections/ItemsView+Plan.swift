// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if MAUI

extension ItemsView {
    /// What sits at one position of the run.
    enum Kind: Hashable {
        /// A group's header.
        case header

        /// One of its items.
        case item

        /// Its footer.
        case footer

        /// What an identity says after the group's own name.
        var suffix: String {
            switch self {
            case .header: return "header"
            case .item: return "item"
            case .footer: return "footer"
            }
        }
    }

    /// One group's shape, which is all the arithmetic needs of it.
    struct GroupShape {
        /// Whether a header stands before its items.
        let header: Bool

        /// How many items it has.
        let items: Int

        /// Whether a footer stands after them.
        let footer: Bool

        /// How many slots the group is, in all.
        var slots: Int { items + (header ? 1 : 0) + (footer ? 1 : 0) }
    }

    /// Which slot a position is, and whose.
    struct Slot {
        /// Which group it belongs to.
        let group: Int

        /// What it is.
        let kind: Kind

        /// Which item of the group, where it is one.
        let offset: Int
    }

    /// Where every group starts, and what each kind of slot is worth; each
    /// running list ends with the total.
    struct Plan {
        /// The first slot of each group, then the total.
        let starts: [Int]

        /// The start of each group along the axis, then the whole length.
        let tops: [Double]

        /// How many items stand before each group, then the total.
        let itemsBefore: [Int]

        /// The shapes it was built from.
        let shapes: [GroupShape]

        /// What an item measured or was stated at; nought while unmeasured.
        let item: Double

        /// What a group's header measured.
        let header: Double

        /// What a group's footer measured.
        let footer: Double

        /// Where every slot starts, then the whole length - built only where
        /// every item is measured.
        let each: [Double]?

        /// Builds the sums, one addition per group.
        init(
            shapes: [GroupShape],
            item: Double,
            header: Double,
            footer: Double,
            lengths: [Double]?
        ) {
            var starts = [0]
            var tops = [0.0]
            var itemsBefore = [0]

            // The lengths `length(of:)` answers, provisional ones included.
            let itemLength = item > 0 ? item : ItemsView.provisional
            let headerLength = header > 0 ? header : ItemsView.provisional
            let footerLength = footer > 0 ? footer : ItemsView.provisional

            for shape in shapes {
                starts.append(starts[starts.count - 1] + shape.slots)
                itemsBefore.append(itemsBefore[itemsBefore.count - 1] + shape.items)
                tops.append(tops[tops.count - 1]
                    + (shape.header ? headerLength : 0)
                    + Double(shape.items) * itemLength
                    + (shape.footer ? footerLength : 0))
            }

            self.starts = starts
            self.tops = tops
            self.itemsBefore = itemsBefore
            self.shapes = shapes
            self.item = item
            self.header = header
            self.footer = footer

            if let lengths {
                var running = [0.0]
                running.reserveCapacity(lengths.count + 1)

                for length in lengths {
                    running.append(running[running.count - 1] + length)
                }

                each = running
            } else {
                each = nil
            }
        }

        /// The step from one item to the next.
        var step: Double { length(of: .item) }

        /// How many slots the whole run is.
        var slots: Int { starts[starts.count - 1] }

        /// How long the whole run is along the axis.
        var extent: Double {
            if let each { return max(0, each[each.count - 1]) }

            return tops[tops.count - 1]
        }

        /// Whether every kind the list has is measured - until then the
        /// arithmetic is provisional and the placed slots measure themselves.
        var settled: Bool {
            !needs(.item) && !needs(.header) && !needs(.footer)
        }

        /// What a kind of slot is worth, provisionally while it has never
        /// been measured.
        func length(of kind: Kind) -> Double {
            let measured: Double

            switch kind {
            case .header: measured = header
            case .item: measured = item
            case .footer: measured = footer
            }

            return measured > 0 ? measured : ItemsView.provisional
        }

        /// Whether a kind the list has is still waiting to be measured. A kind
        /// no group has needs nothing.
        func needs(_ kind: Kind) -> Bool {
            switch kind {
            case .header: return header <= 0 && shapes.contains { $0.header }
            case .item: return item <= 0 && shapes.contains { $0.items > 0 }
            case .footer: return footer <= 0 && shapes.contains { $0.footer }
            }
        }

        /// The first slot of a kind, wherever in the run it falls - what
        /// measures that kind for all of them.
        func first(_ kind: Kind) -> Int? {
            for (index, shape) in shapes.enumerated() {
                switch kind {
                case .header where shape.header:
                    return starts[index]

                case .item where shape.items > 0:
                    return starts[index] + (shape.header ? 1 : 0)

                case .footer where shape.footer:
                    return starts[index] + (shape.header ? 1 : 0) + shape.items

                default:
                    continue
                }
            }

            return nil
        }

        /// How many slots fit in a viewport, counted off the shortest slot so the
        /// answer is never short.
        func fits(in viewport: Double) -> Int {
            max(1, Int((viewport / max(shortest, 1)).rounded(.up)))
        }

        /// The shortest slot the run has.
        private var shortest: Double {
            if let each, each.count > 1 {
                var least = Double.greatestFiniteMagnitude

                for index in 1..<each.count {
                    least = min(least, each[index] - each[index - 1])
                }

                return least
            }

            var least = step

            if shapes.contains(where: { $0.header }) { least = min(least, length(of: .header)) }
            if shapes.contains(where: { $0.footer }) { least = min(least, length(of: .footer)) }

            return least
        }

        /// Which slot a position is, and whose.
        func slot(_ index: Int) -> Slot {
            let group = self.group { starts[$0] <= index }
            let shape = shapes[group]
            var offset = index - starts[group]

            if shape.header {
                if offset == 0 { return Slot(group: group, kind: .header, offset: 0) }
                offset -= 1
            }

            if offset < shape.items { return Slot(group: group, kind: .item, offset: offset) }

            return Slot(group: group, kind: .footer, offset: 0)
        }

        /// Where a slot starts along the axis.
        func start(of index: Int) -> Double {
            if let each { return each[min(max(0, index), each.count - 1)] }

            let slot = slot(index)
            let shape = shapes[slot.group]
            var start = tops[slot.group]

            if shape.header && slot.kind != .header { start += length(of: .header) }
            if slot.kind == .item { start += Double(slot.offset) * step }
            if slot.kind == .footer { start += Double(shape.items) * step }

            return start
        }

        /// How many ITEMS stand after a slot - what the end of the list is
        /// counted in, a group's header and footer being no items.
        func items(after index: Int) -> Int {
            let slot = slot(clamped(index))
            let through: Int

            switch slot.kind {
            case .header: through = 0
            case .item: through = slot.offset + 1
            case .footer: through = shapes[slot.group].items
            }

            return itemsBefore[itemsBefore.count - 1] - itemsBefore[slot.group] - through
        }

        /// A slot the run actually has.
        func clamped(_ index: Int) -> Int { min(max(0, index), max(0, slots - 1)) }

        /// Which slot is at a position along the axis, held to the group's items
        /// before it becomes a whole number.
        func slot(at along: Double) -> Int {
            if let each {
                // The last slot starting at or before the position.
                var low = 0
                var high = each.count - 2

                while low < high {
                    let middle = (low + high + 1) / 2
                    if each[middle] <= along { low = middle } else { high = middle - 1 }
                }

                return clamped(low)
            }

            let group = self.group { tops[$0] <= along }
            let shape = shapes[group]
            var rest = along - tops[group]

            if shape.header {
                if rest < length(of: .header) { return starts[group] }
                rest -= length(of: .header)
            }

            let last = max(0, shape.items - 1)
            let item = rest > 0 ? Int(min(rest / step, Double(last))) : 0

            return clamped(starts[group] + (shape.header ? 1 : 0) + item)
        }

        /// The last group whose start is at or before a position - a binary
        /// search, because a list may have as many groups as it likes.
        private func group(_ isBefore: (Int) -> Bool) -> Int {
            var low = 0
            var high = shapes.count - 1

            while low < high {
                let middle = (low + high + 1) / 2
                if isBefore(middle) { low = middle } else { high = middle - 1 }
            }

            return max(0, low)
        }
    }
}

#endif
