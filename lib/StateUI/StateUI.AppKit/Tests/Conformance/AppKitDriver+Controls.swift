// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAppKit
@_spi(Host) import StateUIConformance

/// What the AppKit driver reads of a control's own: a label's words as its text field lays them out, a field's and
/// an editor's, a box's outline on its layer, a scroller's and a picture's - each from the view AppKit holds.
/// Design: docs/design/platforms/appkit/conformance.md#what-the-driver-reads
extension AppKitDriver {
    static func controlHolds(_ property: Prop, _ view: NSView) throws -> HostValue? {
        if let label = view as? AppKitTextView, let held = labelHolds(property, label) { return held }
        if let held = fieldHolds(property, view) { return held }
        if let held = try boxHolds(property, view) { return held }
        if let button = view as? AppKitButtonView, let held = buttonHolds(property, button) { return held }
        switch (property, view) {
        case (.clipsContent, _) where !(view is NSControl): return view.clipsToBounds.propValue
        case (.scrollOffset, let scroll as NSScrollView):
            let origin = scroll.contentView.bounds.origin
            return Point(x: Double(origin.x), y: Double(origin.y)).propValue
        case (.verticalScrollIndicator, let scroll as NSScrollView):
            return bar(shown: scroll.hasVerticalScroller, hides: scroll.autohidesScrollers).propValue
        case (.horizontalScrollIndicator, let scroll as NSScrollView):
            return bar(shown: scroll.hasHorizontalScroller, hides: scroll.autohidesScrollers).propValue
        case (.isAnimating, let image as AppKitImageView): return image.animationPlaying.propValue
        case (.contentMode, let image as AppKitImageView): return aspect(of: image).propValue
        case (.horizontalTextAlignment, let picker as AppKitPickerView):
            return alignment(picker.presentedControl as? NSControl).propValue
        default: return nil
        }
    }

    /// A label's words as its text field holds and places them.
    private static func labelHolds(_ property: Prop, _ label: AppKitTextView) -> HostValue? {
        guard let field = label.subviews.lazy.compactMap({ $0 as? NSTextField }).first else { return nil }
        let words = field.attributedStringValue
        let attributes = words.length > 0 ? words.attributes(at: 0, effectiveRange: nil) : [:]
        switch property {
        case .maximumLines: return field.maximumNumberOfLines.propValue
        case .lineBreak:
            let wraps = field.cell?.wraps ?? true
            let all: [LineBreak] = [.noWrap, .wordWrap, .characterWrap, .headTruncation, .tailTruncation, .middleTruncation]
            return all.first { NSLineBreakMode($0) == field.lineBreakMode && $0.wraps == wraps }?.propValue
        case .horizontalTextAlignment: return alignment(field).propValue
        case .tracking: return Double((attributes[.kern] as? NSNumber)?.doubleValue ?? 0).propValue
        case .lineHeight:
            guard let font = attributes[.font] as? NSFont,
                  let paragraph = attributes[.paragraphStyle] as? NSParagraphStyle, paragraph.minimumLineHeight > 0
            else { return 1.0.propValue }
            return Double(paragraph.minimumLineHeight / font.boundingRectForFont.height).propValue
        case .textDecorations:
            var decorations: TextDecorations = []
            if (attributes[.underlineStyle] as? Int ?? 0) != 0 { decorations.insert(.underline) }
            if (attributes[.strikethroughStyle] as? Int ?? 0) != 0 { decorations.insert(.strikethrough) }
            return decorations.propValue
        case .padding:
            // The words stand their padding in from the label's edges; a label is as tall as its words.
            let frame = field.frame
            let bounds = label.bounds
            return Insets(
                Double(frame.minX - bounds.minX), Double(frame.minY - bounds.minY),
                Double(bounds.maxX - frame.maxX), Double(bounds.maxY - frame.maxY)).propValue
        default: return nil
        }
    }

    /// The purpose the host's traits were read from: the keys first, then what the traits leave of the words.
    private static func purpose(of traits: InputTraits) -> InputPurpose {
        switch traits.keys {
        case .email: return .email
        case .url: return .url
        case .number: return .numeric
        case .telephone: return .telephone
        case .words:
            if traits.offersEmoji { return .chat }
            switch traits.capitals {
            case .none: return .plain
            case .sentences: return .text
            case .platform: return .default
            }
        }
    }

    /// A field's and an editor's: its placeholder, whether it hides what is typed, how its words stand, and - on an
    /// editor, which keeps them itself - its spelling, its completion and its selection.
    private static func fieldHolds(_ property: Prop, _ view: NSView) -> HostValue? {
        if let editor = view as? AppKitTextEditorView {
            let text = editor.textView
            let placeholder = editor.subviews.lazy.compactMap { $0 as? NSTextField }.first
            switch property {
            case .placeholder: return placeholder?.stringValue.propValue
            case .placeholderColor: return placeholder?.textColor.map { color($0).propValue }
            case .horizontalTextAlignment: return alignment(text.alignment).propValue
            case .isSpellCheckEnabled: return text.isContinuousSpellCheckingEnabled.propValue
            case .isTextPredictionEnabled: return text.isAutomaticTextCompletionEnabled.propValue
            case .cursorPosition: return text.selectedRange().location.propValue
            case .selectionLength: return text.selectedRange().length.propValue
            case .inputPurpose: return purpose(of: editor.traits).propValue
            default: return nil
            }
        }
        if property == .inputPurpose {
            let traits = ((view as? AppKitTextFieldView)?.textField as? AppKitWordsField)?.traits
                ?? (view as? AppKitSearchFieldView)?.traits
            return traits.map { purpose(of: $0).propValue }
        }
        let field: NSTextField? = (view as? AppKitTextFieldView)?.textField ?? view as? AppKitSearchFieldView
        guard let field else { return nil }
        switch property {
        case .placeholder:
            return (field.placeholderAttributedString?.string ?? field.placeholderString)?.propValue
        case .placeholderColor:
            guard let placeholder = field.placeholderAttributedString, placeholder.length > 0 else { return nil }
            return (placeholder.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor).map { color($0).propValue }
        case .isPassword: return (field is NSSecureTextField).propValue
        case .horizontalTextAlignment: return alignment(field).propValue
        default: return nil
        }
    }

    /// A button's icon and how its caption breaks, as the button holds them.
    private static func buttonHolds(_ property: Prop, _ button: AppKitButtonView) -> HostValue? {
        switch property {
        case .lineBreak:
            let all: [LineBreak] = [.noWrap, .wordWrap, .characterWrap, .headTruncation, .tailTruncation, .middleTruncation]
            return all.first { NSLineBreakMode($0) == button.cell?.lineBreakMode }?.propValue
        case .iconPosition:
            let positions: [NSControl.ImagePosition: IconPosition] = [
                .imageAbove: .top, .imageTrailing: .trailing, .imageBelow: .bottom, .imageLeading: .leading,
            ]
            return positions[button.imagePosition]?.propValue
        default: return nil
        }
    }

    /// A button's and a scroller's outline, as its layer draws it.
    private static func boxHolds(_ property: Prop, _ view: NSView) throws -> HostValue? {
        guard view is AppKitButtonView || view is NSScrollView else { return nil }
        let layer = view.layer
        switch property {
        case .stroke:
            guard let outline = layer?.borderColor, (layer?.borderWidth ?? 0) > 0, let color = NSColor(cgColor: outline)
            else { return nil }
            return Brush.solidColor(Self.color(color)).propValue
        case .lineWidth: return Double(layer?.borderWidth ?? 0).propValue
        case .shape:
            if layer?.mask != nil { return ContainerShape.ellipse.propValue }
            let radius = Double(layer?.cornerRadius ?? 0)
            if radius == Double(min(view.bounds.width, view.bounds.height)) / 2 {
                throw DriverCannot("read shape of a box shorter than its radius")
            }
            return (radius > 0 ? ContainerShape.roundedRectangle(radius) : .rectangle).propValue
        default: return nil
        }
    }

    /// How a picture fills its room: by the image view's scaling, and covering where the view stands past it.
    private static func aspect(of image: AppKitImageView) -> ContentMode {
        switch image.nativeImageScaling {
        case .scaleProportionallyUpOrDown: .fit
        case .scaleNone: .center
        default: image.renderedImageFrame == image.bounds ? .stretch : .fill
        }
    }

    /// Where a control's words stand across it, as AppKit aligns them, read in the user's direction.
    private static func alignment(_ control: NSControl?) -> TextAlignment {
        alignment(control?.alignment ?? .natural)
    }

    private static func alignment(_ native: NSTextAlignment) -> TextAlignment {
        switch native {
        case .center: .center
        case .right: NSApp.userInterfaceLayoutDirection == .rightToLeft ? .start : .end
        case .left: NSApp.userInterfaceLayoutDirection == .rightToLeft ? .end : .start
        default: .start
        }
    }

    /// A scroll bar's showing: none, always, or as AppKit decides it - hidden until the user scrolls.
    private static func bar(shown: Bool, hides: Bool) -> ScrollIndicatorVisibility {
        !shown ? .never : hides ? .automatic : .visible
    }
}

#endif
