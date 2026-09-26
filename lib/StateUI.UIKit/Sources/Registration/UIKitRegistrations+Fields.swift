// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension UIKitRegistrations {
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
}
#endif
