// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension UIKitRegistrations {
    /// A Label: its words in their case and their look (`TextMembers`), how they break, where they stand.
    static func text(_ registry: Registry<UIView>) {
        registry.add(LabelContract.self, create: { _ in UIKitLabelView() }) { label in
            label.applies(TextMembers.members) { view, values in
                if let words = TextMembers.words(values) { view.text = words }
                if let look = TextMembers.look(values) { view.setLook(look) }
            }
            label.applies([LabelContract.lineBreak, LabelContract.maximumLines]) { view, values in
                view.setLines(
                    breaking: values[LabelContract.lineBreak] ?? .wordWrap, maximum: values[LabelContract.maximumLines])
            }
            label.applies([
                TextAlignmentElementContract.horizontalTextAlignment,
                TextAlignmentElementContract.verticalTextAlignment,
            ]) { view, values in
                view.setAlignment(
                    horizontal: values[TextAlignmentElementContract.horizontalTextAlignment] ?? .start,
                    vertical: values[TextAlignmentElementContract.verticalTextAlignment] ?? .start)
            }
        }
    }

    /// A Button: its words and their look, and the user's tap as its click.
    static func buttons(_ registry: Registry<UIView>) {
        registry.add(ButtonContract.self, create: { reports in
            let button = UIKitButtonView()
            button.onClicked = { reports.raise(ButtonContract.clicked) }
            return button
        }, members: { button in
            button.applies(TextMembers.members) { view, values in
                if let words = TextMembers.words(values) { view.setText(words) }
                if let look = TextMembers.look(values) { view.setLook(look) }
            }
            button.raises(ButtonContract.clicked)
        })
    }

    /// A TextField: the user's words reported onto the state they are carried in, the program's only written.
    static func fields(_ registry: Registry<UIView>) {
        registry.add(TextFieldContract.self, create: { reports in
            let field = UIKitTextFieldView()
            field.onTextChanged = { typed in
                reports.report(TextElementContract.text, typed, as: InputViewContract.textChanged)
            }
            field.onSubmitted = { reports.raise(TextFieldContract.submitted) }
            return field
        }, members: { field in
            field.applies([
                TextElementContract.text, FontElementContract.fontSize, FontElementContract.fontAttributes,
                FontElementContract.fontFamily, TextStyleElementContract.textColor, InputViewContract.placeholder,
                InputViewContract.maximumLength,
            ]) { view, values in
                if values.changed(TextElementContract.text), !values.carriedIn(TextElementContract.text) {
                    view.setText(values[TextElementContract.text] ?? "")
                }
                if let look = TextMembers.look(values) { view.setLook(look) }
                if values.changed(InputViewContract.placeholder) { view.placeholder = values[InputViewContract.placeholder] }
                view.maximumLength = values[InputViewContract.maximumLength].map { max(0, $0) }
            }
            field.raises(InputViewContract.textChanged)
            field.raises(TextFieldContract.submitted)
        })
    }

    /// An Image: one of the application's pictures, filling its room as its aspect says.
    static func pictures(_ registry: Registry<UIView>) {
        registry.add(ImageContract.self, create: { _ in UIKitImageView() }) { image in
            image.applies([ImageContract.source, ImageElementContract.aspect]) { view, values in
                view.apply(source: values[ImageContract.source], aspect: values[ImageElementContract.aspect] ?? .fit)
            }
        }
    }

    /// A VStack and an HStack: their children one after another, spaced and padded.
    static func layouts(_ registry: Registry<UIView>) {
        registry.add(VStackContract.self, create: { _ in UIKitStackView(axis: .vertical) }) { stack in
            stack.applies([StackBaseContract.spacing, PaddingElementContract.padding]) { view, values in
                view.spacing = values[StackBaseContract.spacing] ?? 0
                view.padding = values[PaddingElementContract.padding] ?? Insets(0)
            }
        }
        registry.add(HStackContract.self, create: { _ in UIKitStackView(axis: .horizontal) }) { stack in
            stack.applies([StackBaseContract.spacing, PaddingElementContract.padding]) { view, values in
                view.spacing = values[StackBaseContract.spacing] ?? 0
                view.padding = values[PaddingElementContract.padding] ?? Insets(0)
            }
        }
    }
}
#endif
