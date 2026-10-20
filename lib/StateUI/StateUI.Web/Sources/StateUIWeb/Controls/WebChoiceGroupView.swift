// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A picker offering its values as segments or as radio buttons: a `radiogroup` - a row of buttons marked as radios,
/// the one chosen checked, or a column of the browser's radio buttons in their labels.
/// Design: docs/design/platforms/web/controls.md#a-pickers-segments-and-radio-buttons
@MainActor
final class WebChoiceGroupView: WebDOMView, WebChoosing {
    var onChosen: (Int) -> Void = { _ in }

    /// Whether the values stand as segments rather than as radio buttons.
    private let segmented: Bool

    /// Each value's own element - a segment, or a radio button's label - and a radio button's input.
    private var choices: [WebDOMView] = []
    private var inputs: [WebDOMView] = []
    private var captions: [WebDOMView] = []
    private var written = PickerChoices()

    init(segmented: Bool) {
        self.segmented = segmented
        super.init(tag: "div")
        attribute("role", "radiogroup")
        attribute("class", segmented ? "stateui-segments" : "stateui-radios")
    }

    override var role: String? { nil }

    override var isControl: Bool { true }

    func setText(_ text: String) {}

    func setChoices(_ choices: [String], chosen: Int, writeChosen: Bool, title words: String?) {
        let write = written.write(choices, chosen: chosen, choiceChanged: writeChosen)
        if let shown = write.choices { offer(shown) }
        if write.writesChoice { mark(write.chosen) }
    }

    /// Stands an element for each of `shown`, in order, each choosing its value as the user clicks it.
    private func offer(_ shown: [String]) {
        releaseChoices()
        for (place, words) in shown.enumerated() {
            if segmented {
                let segment = WebDOMView(tag: "button")
                segment.attribute("type", "button")
                segment.attribute("role", "radio")
                segment.attribute("class", "stateui-segment")
                WebRelay.setText(segment.node, words)
                segment.listen("click") { [weak self] in self?.choose(place) }
                choices.append(segment)
            } else {
                let label = WebDOMView(tag: "label")
                let input = WebDOMView(tag: "input")
                let caption = WebDOMView(tag: "span")
                label.attribute("class", "stateui-radio")
                input.attribute("type", "radio")
                WebRelay.setText(caption.node, words)
                WebRelay.insert(input.node, into: label.node, at: 0)
                WebRelay.insert(caption.node, into: label.node, at: 1)
                input.listen("change") { [weak self] in self?.choose(place) }
                choices.append(label)
                inputs.append(input)
                captions.append(caption)
            }
            WebRelay.insert(choices[place].node, into: node, at: place)
        }
    }

    /// The user chose the value at `place`.
    private func choose(_ place: Int) {
        mark(place)
        onChosen(place)
    }

    /// Checks the value at `chosen`, none for nil, and no other.
    private func mark(_ chosen: Int?) {
        for (place, choice) in choices.enumerated() {
            if segmented {
                choice.attribute("aria-checked", place == chosen ? "true" : "false")
            } else {
                WebRelay.setFlag(inputs[place].node, "checked", place == chosen)
            }
        }
    }

    override func setEnabled(_ enabled: Bool) {
        for choice in segmented ? choices : inputs { choice.attribute("disabled", enabled ? nil : "") }
        for label in segmented ? [] : choices { label.attribute("aria-disabled", enabled ? nil : "true") }
    }

    private func releaseChoices() {
        for view in inputs + captions + choices { view.release() }
        (choices, inputs, captions) = ([], [], [])
    }

    override func release() {
        releaseChoices()
        super.release()
    }
}
