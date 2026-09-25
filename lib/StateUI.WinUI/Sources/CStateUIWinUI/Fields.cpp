// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The words the user types: a field on one line, whose Enter submits; an
// editor of several lines, whose Enter starts a new one; and a search box,
// WinUI's AutoSuggestBox, whose query submits. Each change of the words is told
// through `textChanged` as it happens.
// Design: docs/design/platforms/winui/controls.md#a-field-and-its-words

#include "Automation.h"

#include <algorithm>
#include <cstring>
#include <vector>

#include <winrt/Windows.System.h>
#include <winrt/Windows.UI.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>

using namespace stateui;
namespace media = winrt::Microsoft::UI::Xaml::Media;

namespace {
    /// Tells the view `view` of each change of the box's words. TextChanging, not TextChanged: it is raised in the
    /// write that makes it, so a program's write is known as one, where TextChanged comes later.
    void hearWords(controls::TextBox const &box, int64_t view) {
        box.TextChanging([view](controls::TextBox const &sender, controls::TextBoxTextChangingEventArgs const &args) {
            if (!args.IsContentChanging()) return;
            auto bytes = winrt::to_string(sender.Text());
            callbacks.textChanged(view, bytes.c_str());
        });
    }
}

extern "C" StateUIObjectRef stateui_winui_field_make(int64_t view) {
    try {
        controls::TextBox field;
        hearWords(field, view);
        field.KeyDown([view](IInspectable const &, xaml::Input::KeyRoutedEventArgs const &args) {
            if (args.Key() == winrt::Windows::System::VirtualKey::Enter) callbacks.submitted(view);
        });
        return detach(field);
    } catch (winrt::hresult_error const &error) {
        report(error, "making a field");
        return nullptr;
    }
}

extern "C" StateUIObjectRef stateui_winui_editor_make(int64_t view) {
    try {
        controls::TextBox editor;
        editor.AcceptsReturn(true);
        editor.TextWrapping(xaml::TextWrapping::Wrap);
        controls::ScrollViewer::SetVerticalScrollBarVisibility(editor, controls::ScrollBarVisibility::Auto);
        hearWords(editor, view);
        return detach(editor);
    } catch (winrt::hresult_error const &error) {
        report(error, "making an editor");
        return nullptr;
    }
}

extern "C" StateUIObjectRef stateui_winui_search_make(int64_t view) {
    try {
        controls::AutoSuggestBox search;
        search.QueryIcon(controls::SymbolIcon(controls::Symbol::Find));
        search.TextChanged([view](controls::AutoSuggestBox const &sender, controls::AutoSuggestBoxTextChangedEventArgs const &args) {
            if (args.Reason() != controls::AutoSuggestionBoxTextChangeReason::UserInput) return;
            auto bytes = winrt::to_string(sender.Text());
            callbacks.textChanged(view, bytes.c_str());
        });
        search.QuerySubmitted([view](controls::AutoSuggestBox const &, controls::AutoSuggestBoxQuerySubmittedEventArgs const &) {
            callbacks.submitted(view);
        });
        return detach(search);
    } catch (winrt::hresult_error const &error) {
        report(error, "making a search box");
        return nullptr;
    }
}

extern "C" void stateui_winui_field_set_text(StateUIObjectRef handle, char const *utf8) {
    try {
        auto words = text(utf8);
        auto control = as<IInspectable>(handle);
        if (auto search = control.try_as<controls::AutoSuggestBox>()) {
            if (search.Text() != words) search.Text(words);
            return;
        }
        auto field = control.as<controls::TextBox>();
        if (field.Text() == words) return;
        field.Text(words);
        field.Select(static_cast<int32_t>(words.size()), 0);
    } catch (winrt::hresult_error const &error) {
        report(error, "setting a field's words");
    }
}

extern "C" void stateui_winui_field_set_placeholder(StateUIObjectRef handle, char const *utf8) {
    try {
        auto control = as<IInspectable>(handle);
        if (auto search = control.try_as<controls::AutoSuggestBox>()) search.PlaceholderText(text(utf8));
        else control.as<controls::TextBox>().PlaceholderText(text(utf8));
    } catch (winrt::hresult_error const &error) {
        report(error, "setting a field's placeholder");
    }
}

extern "C" void stateui_winui_field_set_behaviour(
    StateUIObjectRef handle, bool readOnly, bool spellChecked, bool predicted, int32_t purpose
) {
    try {
        auto field = borrow<controls::TextBox>(handle);
        field.IsReadOnly(readOnly);
        field.IsSpellCheckEnabled(spellChecked);
        field.IsTextPredictionEnabled(predicted);
        field.InputScope(inputScope(purpose));
    } catch (winrt::hresult_error const &error) {
        report(error, "setting how a field takes words");
    }
}

extern "C" void stateui_winui_field_set_look(StateUIObjectRef handle, int32_t alignment, uint32_t placeholderArgb, bool placeholderColored) {
    try {
        auto field = borrow<controls::TextBox>(handle);
        field.TextAlignment(alignment == 1 ? xaml::TextAlignment::Center
                            : alignment == 2 ? xaml::TextAlignment::Right
                                             : xaml::TextAlignment::Left);
        if (placeholderColored)
            field.PlaceholderForeground(media::SolidColorBrush(winrt::Windows::UI::Color{
                static_cast<uint8_t>(placeholderArgb >> 24), static_cast<uint8_t>(placeholderArgb >> 16),
                static_cast<uint8_t>(placeholderArgb >> 8), static_cast<uint8_t>(placeholderArgb)}));
        else
            field.ClearValue(controls::TextBox::PlaceholderForegroundProperty());
    } catch (winrt::hresult_error const &error) {
        report(error, "setting a field's look");
    }
}

extern "C" void stateui_winui_field_select(StateUIObjectRef handle, int32_t start, int32_t length) {
    try {
        auto field = borrow<controls::TextBox>(handle);
        auto size = static_cast<int32_t>(field.Text().size());
        auto from = std::clamp(start, 0, size);
        field.Select(from, std::clamp(length, 0, size - from));
    } catch (winrt::hresult_error const &error) {
        report(error, "selecting in a field");
    }
}

extern "C" void stateui_winui_field_facts(StateUIObjectRef handle, int32_t *facts) {
    try {
        auto field = borrow<controls::TextBox>(handle);
        auto names = field.InputScope() ? field.InputScope().Names() : nullptr;
        int32_t const read[] = {
            field.IsReadOnly(), field.IsSpellCheckEnabled(), field.IsTextPredictionEnabled(),
            names && names.Size() > 0 ? static_cast<int32_t>(names.GetAt(0).NameValue()) : -1,
            static_cast<int32_t>(field.TextAlignment()), field.SelectionStart(), field.SelectionLength(),
            field.PlaceholderForeground() != nullptr, field.AcceptsReturn(),
        };
        std::memcpy(facts, read, sizeof read);
    } catch (winrt::hresult_error const &error) {
        report(error, "reading a field");
    }
}

extern "C" void stateui_winui_search_type(StateUIObjectRef handle, char const *utf8) {
    try {
        // The box's own text box, which its template holds: words changed there are the user's to the search box.
        std::vector<xaml::DependencyObject> left{as<xaml::DependencyObject>(handle)};
        while (!left.empty()) {
            auto at = left.back();
            left.pop_back();
            if (auto box = at.try_as<controls::TextBox>()) {
                box.Text(text(utf8));
                return;
            }
            for (int32_t index = 0, count = media::VisualTreeHelper::GetChildrenCount(at); index < count; ++index)
                left.push_back(media::VisualTreeHelper::GetChild(at, index));
        }
    } catch (winrt::hresult_error const &error) {
        report(error, "typing in a search box");
    }
}

extern "C" void stateui_winui_search_submit_as_user(StateUIObjectRef handle) {
    try {
        // A search box's automation peer submits its query as its own button does.
        pattern<provider::IInvokeProvider>(as<xaml::UIElement>(handle), PatternInterface::Invoke).Invoke();
    } catch (winrt::hresult_error const &error) {
        report(error, "submitting a search as the user");
    }
}
