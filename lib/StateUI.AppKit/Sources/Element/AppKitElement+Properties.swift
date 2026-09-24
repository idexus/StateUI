// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

/// The native view: made, and given the element's properties.
extension AppKitElement {
    /// Properties a parent reads into its child's layout item. A frame that
    /// moves one of them makes the parent arrange again; no other frame
    /// arranges an ancestor.
    static let arrangedProperties: Set<Prop> = [
        .margin, .horizontalAlignment, .verticalAlignment,
        .width, .height,
        .minimumWidth, .minimumHeight,
        .maximumWidth, .maximumHeight,
        .gridRow, .gridColumn, .gridRowSpan, .gridColumnSpan,
        .area,
    ]

    /// Properties whose change is drawn without changing any native
    /// measurement. Applying any other property may change a view's size, so
    /// it forgets the measurements from that view up to its window.
    static let unmeasuredProperties: Set<Prop> = [
        .opacity, .translationX, .translationY,
        .rotation, .rotationX, .rotationY, .scale, .scaleX, .scaleY,
        .pivotX, .pivotY,
        .background, .color, .textColor, .placeholderColor,
        .tint, .stroke, .fill, .strokeWidth,
        .strokeDashPattern, .strokeDashOffset, .strokeLineCap, .strokeLineJoin,
        .strokeMiterLimit, .shape, .cornerRadius, .renderTransform,
        .barBackgroundColor, .barForegroundColor,
        .drawable, .value, .progress, .scrollOffset, .isOn, .isEnabled,
        .ignoresInput, .letsInputThrough,
        .accessibilityIdentifier, .isAccessibilityHidden, .automationExcludedWithChildren,
        .accessibilityLabel, .accessibilityHint, .accessibilityHeadingLevel,
    ]

    /// Only properties whose native presentation lives outside the mounted
    /// content view need the scene/window reconciliation path. Ordinary view
    /// frames are already applied in place and AppKit lays them out before the
    /// display link's frame is drawn.
    func needsWindowSynchronization(for properties: Set<Prop>) -> Bool {
        guard !properties.isEmpty else { return false }
        return type == .window || type == .titleBar || type == .navigationStack
    }

    func makeView() -> NSView? {
        if let registered = AppKitRegistrations.registry.makeView(
            for: type,
            sending: { [weak self] event, values in self?.send(event, values) },
            reporting: { [weak self] property, event, value in self?.report(property, event, value) }
        ) {
            // A picture crosses as a file NAME, and the files are the
            // renderer's: it holds the resource directory and the cache over
            // it. A registration is made once for the process and has no
            // renderer to ask, so a view that draws pictures is given the way
            // to resolve one here, where it is made.
            if let drawing = registered as? any AppKitPictureResolving {
                drawing.picture = { [weak self] name in self?.image(named: name) }
            }

            return registered
        }

        switch type {
        case .application, .scene, .window:
            return nil

        case .page:
            let page = AppKitSingleChildView()
            page.translatesAutoresizingMaskIntoConstraints = true
            return page

        case .modalStack, .titleBar, .content, .leadingContent, .trailingContent,
             .titleView, .toolbarItems, .menuBar, .contextMenu,
             .menu, .menuItem,
             .menuSeparator, .spans, .span:
            return nil

        case .navigationStack:
            return AppKitNavigationView()

        case .tabbedView:
            return AppKitTabbedView()

        case .splitView:
            return AppKitSplitView()

        case .zStack:
            return AppKitZStackView()


        case .scrollView:
            let scroll = AppKitScrollView()
            scroll.onOffsetChanged = { [weak self] old, new in
                self?.scrolled(from: old, to: new)
            }
            scroll.onScrollStopped = { [weak self] in self?.scrollStopped() }
            scroll.onFramesWanted = { [weak self, weak scroll] in
                guard let scroll else { return }
                self?.host?.requestFrames(for: scroll)
            }
            return scroll

        case .label:
            return AppKitLabelView()

        case .toolbarItem:
            // The window's toolbar makes the native item; see visibleToolbarActions.
            return nil

        default:
            return AppKitUnsupportedView(type)
        }
    }

    /// The layout's own placement run, where a state drives one: the room's
    /// arithmetic over the children, which moves them without changing what
    /// the layout measures - a run is not part of its natural size.
    var ownPlacementRun: Set<Prop> {
        driven[.area]?.kind == .placement ? [.area] : []
    }

    func applyProperties(changed: Set<Prop>) {
        guard let view else { return }

        if !changed.subtracting(ownPlacementRun).isSubset(of: Self.unmeasuredProperties) {
            view.invalidateMeasurements()
        }

        applyVisibility()
        if let scroll = view as? AppKitScrollView {
            scroll.boxBackground = color(.background)
        } else if !(view is AppKitTravellingLayout) && !(view is AppKitColorBoxView) {
            let background = color(.background)
            view.wantsLayer = true
            view.layer?.backgroundColor = background?.cgColor
        }

        // A family the registry realizes takes its own members there, each read
        // as this element presents it; the arms below are the families still
        // to move.
        AppKitRegistrations.registry.apply(
            changed, to: view, of: type,
            reading: { self.value($0) },
            carriedIn: { self.driven[$0]?.mode == .in })

        if type == .toolbarItem, let button = view as? NSButton {
            button.title = string(.text) ?? ""
            let buttonFont = font(fallback: NSFont.systemFont(ofSize: NSFont.systemFontSize))
            button.font = buttonFont
            button.isEnabled = value(.isEnabled)?.bool ?? true

            let foreground = value(.isDestructive)?.bool == true
                ? NSColor.systemRed
                : (color(.textColor) ?? .controlTextColor)
            button.attributedTitle = NSAttributedString(
                string: button.title,
                attributes: [.font: buttonFont, .foregroundColor: foreground])

            button.image = string(.icon).flatMap { image(named: $0) }
            button.imagePosition = button.image == nil
                ? .noImage
                : (button.title.isEmpty ? .imageOnly : .imageLeading)

            let background = color(.background)
            button.isBordered = background == nil
            button.wantsLayer = background != nil
            button.layer?.backgroundColor = background?.cgColor
        }

        if let split = view as? AppKitSplitView {
            // THE VALUE IS THE REGISTRY'S; THIS REPORT IS THE HOST'S. A change
            // the user makes walks into the first child's page lifetime,
            // which no contract describes, so the closure stays here.
            split.onPresentationChanged = { [weak self] presented in
                self?.changeSidebarVisibility(to: presented)
            }
        }

        if let layers = view as? AppKitZStackView {
            layers.placement = placement(.area)
            layers.padding = insets(.padding)
        }

        if let layout = view as? AppKitTravellingLayout {
            layout.decoration.apply(
                backgroundColor: color(.background), background: value(.background), stroke: value(.stroke),
                strokeWidth: value(.strokeWidth)?.number, shape: value(.shape),
                clips: value(.clipsContent)?.bool ?? false, to: layout)
        }

        let minimumWidth = requested(.minimumWidth)
        let minimumHeight = requested(.minimumHeight)
        let maximumWidth = requested(.maximumWidth).map { max($0, minimumWidth ?? 0) }
        let maximumHeight = requested(.maximumHeight).map { max($0, minimumHeight ?? 0) }
        widthConstraint = reconciledConstraint(
            widthConstraint,
            value: requested(.width).map {
                CGFloat(Extent.bounded(Double($0), minimum: minimumWidth.map(Double.init), maximum: maximumWidth.map(Double.init)))
            },
            make: { view.widthAnchor.constraint(equalToConstant: $0) })
        heightConstraint = reconciledConstraint(
            heightConstraint,
            value: requested(.height).map {
                CGFloat(Extent.bounded(Double($0), minimum: minimumHeight.map(Double.init), maximum: maximumHeight.map(Double.init)))
            },
            make: { view.heightAnchor.constraint(equalToConstant: $0) })
        minimumWidthConstraint = reconciledConstraint(
            minimumWidthConstraint,
            value: minimumWidth,
            make: { view.widthAnchor.constraint(greaterThanOrEqualToConstant: $0) })
        minimumHeightConstraint = reconciledConstraint(
            minimumHeightConstraint,
            value: minimumHeight,
            make: { view.heightAnchor.constraint(greaterThanOrEqualToConstant: $0) })
        maximumWidthConstraint = reconciledConstraint(
            maximumWidthConstraint,
            value: maximumWidth,
            make: { view.widthAnchor.constraint(lessThanOrEqualToConstant: $0) })
        maximumHeightConstraint = reconciledConstraint(
            maximumHeightConstraint,
            value: maximumHeight,
            make: { view.heightAnchor.constraint(lessThanOrEqualToConstant: $0) })

        if let button = view as? NSButton,
           let padding = value(.padding)?.numbers, padding.count >= 4 {
            let intrinsic = button.intrinsicContentSize
            buttonWidthConstraint = reconciledConstraint(
                buttonWidthConstraint,
                value: intrinsic.width + padding[0] + padding[2],
                make: {
                    let constraint = button.widthAnchor.constraint(
                        greaterThanOrEqualToConstant: $0)
                    constraint.priority = .defaultHigh
                    return constraint
                })
            buttonHeightConstraint = reconciledConstraint(
                buttonHeightConstraint,
                value: intrinsic.height + padding[1] + padding[3],
                make: {
                    let constraint = button.heightAnchor.constraint(
                        greaterThanOrEqualToConstant: $0)
                    constraint.priority = .defaultHigh
                    return constraint
                })
        } else {
            buttonWidthConstraint?.isActive = false
            buttonWidthConstraint = nil
            buttonHeightConstraint?.isActive = false
            buttonHeightConstraint = nil
        }

        drawing?.own = drawingTransform()
        // Last, so the words meet the control as configured above - a text
        // field may just have swapped in a password field.
        applyAccessibility(to: view)
    }

    /// The view's own drawing transform. `scale` multiplies both axes on
    /// top of `scaleX` and `scaleY`.
    func drawingTransform() -> HostDrawingTransform {
        let scale = value(.scale)?.number ?? 1
        return HostDrawingTransform(
            translationX: value(.translationX)?.number ?? 0,
            translationY: value(.translationY)?.number ?? 0,
            rotation: value(.rotation)?.number ?? 0,
            rotationX: value(.rotationX)?.number ?? 0,
            rotationY: value(.rotationY)?.number ?? 0,
            scaleX: scale * (value(.scaleX)?.number ?? 1),
            scaleY: scale * (value(.scaleY)?.number ?? 1),
            pivotX: value(.pivotX)?.number ?? 0.5,
            pivotY: value(.pivotY)?.number ?? 0.5)
    }

    /// Keeps the native constraint identity stable while a host channel moves
    /// its constant. Creating and tearing down the Auto Layout graph on every
    /// display frame is both unnecessary work and visible as uneven motion.
    func reconciledConstraint(
        _ existing: NSLayoutConstraint?,
        value: CGFloat?,
        make: (CGFloat) -> NSLayoutConstraint
    ) -> NSLayoutConstraint? {
        guard let value else {
            existing?.isActive = false
            return nil
        }

        if let existing {
            existing.constant = value
            return existing
        }

        let constraint = make(value)
        constraint.isActive = true
        return constraint
    }

    /// Resolves an image-valued property through the host's resource policy.
    func image(_ property: Prop) -> NSImage? {
        string(property).flatMap { image(named: $0) }
    }

    func enumeration(_ property: Prop) -> Int32? {
        value(property)?.enumeration
    }

    func whole(_ property: Prop) -> Int? {
        guard let number = value(property)?.number, number.isFinite else { return nil }
        return Int(number.rounded())
    }

    func font(fallback: NSFont) -> NSFont {
        appKitFont(
            family: name(.fontFamily),
            size: value(.fontSize)?.number,
            attributes: value(.fontAttributes)?.enumeration,
            fallback: fallback)
    }

    func attributedLabelText() -> NSAttributedString {
        let baseFont = font(fallback: NSFont.systemFont(ofSize: NSFont.systemFontSize))
        let baseColor = color(.textColor) ?? .labelColor
        let formatted = slot(.spans)
        let runs = formatted?.children ?? [self]
        let result = NSMutableAttributedString()

        for run in runs where run.type == .span || run === self {
            let source = run.string(.text) ?? ""
            let text = run.transformed(source, by: run.enumeration(.textCase))
            let font = run === self ? baseFont : run.font(fallback: baseFont)
            let color = run === self ? baseColor : (run.color(.textColor) ?? baseColor)
            let spacing = run.number(.characterSpacing) ?? number(.characterSpacing) ?? 0
            let decorations = run.enumeration(.textDecorations)
                ?? enumeration(.textDecorations) ?? 0
            let lineHeight = run.number(.lineHeight) ?? number(.lineHeight)
            var attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color,
                .kern: spacing,
            ]

            if run !== self, let background = run.color(.background) {
                attributes[.backgroundColor] = background
            }
            if decorations & 1 == 1 {
                attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }
            if decorations & 2 == 2 {
                attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            }
            if let lineHeight, lineHeight.isFinite, lineHeight > 0 {
                let paragraph = NSMutableParagraphStyle()
                let height = font.boundingRectForFont.height * lineHeight
                paragraph.minimumLineHeight = height
                paragraph.maximumLineHeight = height
                attributes[.paragraphStyle] = paragraph
            }

            result.append(NSAttributedString(string: text, attributes: attributes))
        }

        return result
    }

    func effectiveMaximumLines() -> Int {
        switch enumeration(.lineBreak) {
        case 0, 3, 4, 5: return 1
        default: return max(0, whole(.maximumLines) ?? 0)
        }
    }

    /// The text a field shows from its state. The value this frame carries
    /// comes first: a user's report reaches the core's store only when its
    /// jobs run, so reading the store here would write the field back one
    /// keystroke behind the user.
    func transformed(_ text: String, by transform: Int32?) -> String {
        appKitTextCased(text, transform)
    }

    func color(_ property: Prop) -> NSColor? {
        value(property).flatMap(nsColor)
    }

    func image(named name: String) -> NSImage? {
        host?.image(named: name)
    }

    func transformComponents(_ property: Prop) -> [Double]? {
        guard let components = value(property)?.values, components.count == 6 else {
            return nil
        }

        let numbers = components.compactMap(\.number)
        return numbers.count == components.count ? numbers : nil
    }

    func insets(_ property: Prop) -> NSEdgeInsets {
        guard let numbers = value(property)?.numbers, numbers.count >= 4 else {
            return NSEdgeInsets()
        }

        return NSEdgeInsets(
            top: numbers[1], left: numbers[0], bottom: numbers[3], right: numbers[2])
    }

    /// A negative request is StateUI's explicit "measure me" sentinel. Keep
    /// it out of both Auto Layout and the frame-based layout algorithms so the
    /// native control's fitting size remains authoritative.
    func requested(_ property: Prop) -> CGFloat? {
        guard let value = number(property), value.isFinite, value >= 0 else { return nil }
        return CGFloat(value)
    }

    func placement(_ property: Prop) -> HostPlacementRun? {
        guard driven[property]?.kind == .placement, let carried = element.carriedValue(property) else { return nil }

        return StateUIHost.placements(from: carried)
    }

    func textAlignment(_ value: Int32?) -> NSTextAlignment {
        appKitTextAlignment(value)
    }

    func lineBreakMode(_ mode: Int32?) -> NSLineBreakMode {
        switch mode {
        case 0: return .byClipping
        case 1: return .byWordWrapping
        case 2: return .byCharWrapping
        case 3: return .byTruncatingHead
        case 4: return .byTruncatingTail
        case 5: return .byTruncatingMiddle
        default: return .byWordWrapping
        }
    }
}
#endif
