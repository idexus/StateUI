// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The words the user types: a field on one line, whose Enter submits - a
// PasswordBox while it holds a password; an editor of several lines, whose
// Enter starts a new one; and a search box, WinUI's AutoSuggestBox, whose query
// submits. Each change the user makes is told through `textChanged` as it happens.
// Design: docs/design/platforms/winui/controls.md#a-field-and-its-words

#include "Automation.h"

#include <algorithm>
#include <cstring>
#include <vector>

#include <winrt/Windows.System.h>
#include <winrt/Windows.UI.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>
#include <winrt/Windows.UI.Xaml.Interop.h>

using namespace stateui;
namespace media = winrt::Microsoft::UI::Xaml::Media;

namespace {
    /// Tells the view `view` of each change of the box's words. TextChanging, not TextChanged: it is raised in the
    /// write that makes it, so a program's write is known as one, where TextChanged comes later.
    void hearWords(controls::TextBox const &box, int64_t view) {
        box.TextChanging(guarded("handling TextChanging",
            [view](controls::TextBox const &sender, controls::TextBoxTextChangingEventArgs const &args) {
            if (!args.IsContentChanging()) return;
            auto bytes = winrt::to_string(sender.Text());
            callbacks.textChanged(view, bytes.c_str());
        }));
    }

    /// The words across a text box for StateUI's `TextAlignment`: centred, at the end, or at the start.
    xaml::TextAlignment across(int32_t alignment) {
        return alignment == 1 ? xaml::TextAlignment::Center
               : alignment == 2 ? xaml::TextAlignment::Right
                                : xaml::TextAlignment::Left;
    }

    media::SolidColorBrush brush(uint32_t argb) {
        return media::SolidColorBrush(winrt::Windows::UI::Color{
            static_cast<uint8_t>(argb >> 24), static_cast<uint8_t>(argb >> 16), static_cast<uint8_t>(argb >> 8),
            static_cast<uint8_t>(argb)});
    }

    /// The theme resources a text box's template reads its placeholder's colour from - at rest, under the pointer,
    /// focused and disabled.
    constexpr wchar_t const *placeholderResources[] = {
        L"TextControlPlaceholderForeground", L"TextControlPlaceholderForegroundPointerOver",
        L"TextControlPlaceholderForegroundFocused", L"TextControlPlaceholderForegroundDisabled"};

    /// The case a text box puts typed letters in for StateUI's `TextCase`: upper, lower, or as typed.
    controls::CharacterCasing casing(int32_t textCase) {
        return textCase == 3   ? controls::CharacterCasing::Upper
               : textCase == 2 ? controls::CharacterCasing::Lower
                               : controls::CharacterCasing::Normal;
    }

    /// Tells the view `view` that Enter was pressed in `field`.
    void hearEnter(controls::Control const &field, int64_t view) {
        field.KeyDown(guarded("handling KeyDown",
            [view](IInspectable const &, xaml::Input::KeyRoutedEventArgs const &args) {
            if (args.Key() == winrt::Windows::System::VirtualKey::Enter) callbacks.submitted(view);
        }));
    }

    /// The only scopes a password box takes: digits for the number scope (4), a password's otherwise.
    xaml::Input::InputScope passwordScope(int32_t number) {
        xaml::Input::InputScope scope;
        xaml::Input::InputScopeName name;
        name.NameValue(number == 4 ? xaml::Input::InputScopeNameValue::NumericPin
                                   : xaml::Input::InputScopeNameValue::Password);
        scope.Names().Append(name);
        return scope;
    }

    /// The text box a field or an editor is, or the one a search box's template holds; null before it stands, and
    /// for a password box.
    controls::TextBox boxOf(StateUIObjectRef handle) {
        auto control = as<IInspectable>(handle);
        if (auto search = control.try_as<controls::AutoSuggestBox>()) return first<controls::TextBox>(search);
        return control.try_as<controls::TextBox>();
    }
}

extern "C" StateUIObjectRef stateui_winui_field_make(int64_t view) {
    try {
        controls::TextBox field;
        hearWords(field, view);
        hearEnter(field, view);
        return detach(field);
    } catch (...) {
        report("making a field");
        return nullptr;
    }
}

extern "C" StateUIObjectRef stateui_winui_password_make(int64_t view) {
    try {
        controls::PasswordBox field;
        // PasswordChanging, as a text box's TextChanging: raised in the write that makes it.
        field.PasswordChanging(guarded("handling PasswordChanging", [view](controls::PasswordBox const &sender,
                                      controls::PasswordBoxPasswordChangingEventArgs const &args) {
            if (!args.IsContentChanging()) return;
            auto bytes = winrt::to_string(sender.Password());
            callbacks.textChanged(view, bytes.c_str());
        }));
        hearEnter(field, view);
        return detach(field);
    } catch (...) {
        report("making a password field");
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
    } catch (...) {
        report("making an editor");
        return nullptr;
    }
}

extern "C" StateUIObjectRef stateui_winui_search_make(int64_t view) {
    try {
        controls::AutoSuggestBox search;
        search.QueryIcon(controls::SymbolIcon(controls::Symbol::Find));
        search.TextChanged(guarded("handling TextChanged",
            [view](controls::AutoSuggestBox const &sender, controls::AutoSuggestBoxTextChangedEventArgs const &args) {
            if (args.Reason() != controls::AutoSuggestionBoxTextChangeReason::UserInput) return;
            auto bytes = winrt::to_string(sender.Text());
            callbacks.textChanged(view, bytes.c_str());
        }));
        search.QuerySubmitted(guarded("handling QuerySubmitted",
            [view](controls::AutoSuggestBox const &, controls::AutoSuggestBoxQuerySubmittedEventArgs const &) {
            callbacks.submitted(view);
        }));
        return detach(search);
    } catch (...) {
        report("making a search box");
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
        if (auto password = control.try_as<controls::PasswordBox>()) {
            if (password.Password() != words) password.Password(words);
            return;
        }
        auto field = control.as<controls::TextBox>();
        if (field.Text() == words) return;
        field.Text(words);
        field.Select(static_cast<int32_t>(words.size()), 0);
    } catch (...) {
        report("setting a field's words");
    }
}

extern "C" void stateui_winui_field_set_placeholder(StateUIObjectRef handle, char const *utf8) {
    try {
        auto control = as<IInspectable>(handle);
        if (auto search = control.try_as<controls::AutoSuggestBox>()) search.PlaceholderText(text(utf8));
        else if (auto password = control.try_as<controls::PasswordBox>()) password.PlaceholderText(text(utf8));
        else control.as<controls::TextBox>().PlaceholderText(text(utf8));
    } catch (...) {
        report("setting a field's placeholder");
    }
}

extern "C" void stateui_winui_field_set_behaviour(
    StateUIObjectRef handle, bool readOnly, bool spellChecked, bool predicted, int32_t scope
) {
    try {
        // A password box has no read-only state, spell checking or prediction.
        if (auto password = as<IInspectable>(handle).try_as<controls::PasswordBox>()) {
            password.InputScope(passwordScope(scope));
            return;
        }
        auto field = borrow<controls::TextBox>(handle);
        field.IsReadOnly(readOnly);
        field.IsSpellCheckEnabled(spellChecked);
        field.IsTextPredictionEnabled(predicted);
        field.InputScope(inputScope(scope));
    } catch (...) {
        report("setting how a field takes words");
    }
}

extern "C" void stateui_winui_field_set_casing(StateUIObjectRef handle, int32_t textCase) {
    try {
        if (auto field = as<IInspectable>(handle).try_as<controls::TextBox>()) field.CharacterCasing(casing(textCase));
    } catch (...) {
        report("setting the case a field's typing takes");
    }
}

extern "C" void stateui_winui_search_set_box(
    StateUIObjectRef handle, bool readOnly, int32_t textCase, int32_t alignment, bool spellChecked, bool predicted,
    int32_t scope
) {
    try {
        // The box types in the text box its template holds, which takes the style the box gives it: WinUI's own,
        // with the case typing takes, whether it is read only, the words typed across it - its template stands the
        // placeholder at the start whatever the text box says - and how typing is checked, predicted and keyed.
        xaml::Style style{winrt::xaml_typename<controls::TextBox>()};
        auto own = xaml::Application::Current().Resources().TryLookup(winrt::box_value(L"AutoSuggestBoxTextBoxStyle"));
        if (own) style.BasedOn(own.as<xaml::Style>());
        auto setters = style.Setters();
        setters.Append(xaml::Setter(controls::TextBox::CharacterCasingProperty(), winrt::box_value(casing(textCase))));
        setters.Append(xaml::Setter(controls::TextBox::IsReadOnlyProperty(), winrt::box_value(readOnly)));
        setters.Append(xaml::Setter(controls::TextBox::TextAlignmentProperty(), winrt::box_value(across(alignment))));
        setters.Append(xaml::Setter(controls::TextBox::IsSpellCheckEnabledProperty(), winrt::box_value(spellChecked)));
        setters.Append(xaml::Setter(controls::TextBox::IsTextPredictionEnabledProperty(), winrt::box_value(predicted)));
        setters.Append(xaml::Setter(controls::TextBox::InputScopeProperty(), inputScope(scope)));
        borrow<controls::AutoSuggestBox>(handle).TextBoxStyle(style);
    } catch (...) {
        report("setting how a search box takes words");
    }
}

extern "C" void stateui_winui_search_set_placeholder_color(StateUIObjectRef handle, uint32_t argb, bool colored) {
    try {
        // The template reads its placeholder's colour from the theme resources, which the box's own name again.
        std::vector<std::pair<std::wstring, xaml::Media::Brush>> brushes;
        for (auto name : placeholderResources)
            brushes.emplace_back(name, colored ? brush(argb) : xaml::Media::Brush{nullptr});
        writeResources(borrow<controls::AutoSuggestBox>(handle), brushes);
    } catch (...) {
        report("colouring a search box's placeholder");
    }
}

extern "C" void stateui_winui_field_set_look(StateUIObjectRef handle, int32_t alignment, uint32_t placeholderArgb, bool placeholderColored) {
    try {
        // A password box has no alignment of its own, and colours its placeholder from the theme resources its
        // template reads.
        if (auto password = as<IInspectable>(handle).try_as<controls::PasswordBox>()) {
            std::vector<std::pair<std::wstring, xaml::Media::Brush>> brushes;
            for (auto name : placeholderResources)
                brushes.emplace_back(name, placeholderColored ? brush(placeholderArgb) : xaml::Media::Brush{nullptr});
            writeResources(password, brushes);
            return;
        }
        auto field = borrow<controls::TextBox>(handle);
        field.TextAlignment(across(alignment));
        if (placeholderColored)
            field.PlaceholderForeground(brush(placeholderArgb));
        else
            field.ClearValue(controls::TextBox::PlaceholderForegroundProperty());
    } catch (...) {
        report("setting a field's look");
    }
}

extern "C" void stateui_winui_field_select(StateUIObjectRef handle, int32_t start, int32_t length) {
    try {
        // A password box puts no caret where it is told.
        auto field = as<IInspectable>(handle).try_as<controls::TextBox>();
        if (!field) return;
        auto size = static_cast<int32_t>(field.Text().size());
        auto from = std::clamp(start, 0, size);
        field.Select(from, std::clamp(length, 0, size - from));
    } catch (...) {
        report("selecting in a field");
    }
}

extern "C" void stateui_winui_field_facts(StateUIObjectRef handle, int32_t *facts) {
    try {
        auto field = boxOf(handle);
        if (!field) {
            // A password box holds none of these.
            int32_t const none[] = {0, 0, 0, -1, 0, 0, 0, 0, 0};
            std::memcpy(facts, none, sizeof none);
            return;
        }
        auto names = field.InputScope() ? field.InputScope().Names() : nullptr;
        int32_t const read[] = {
            field.IsReadOnly(), field.IsSpellCheckEnabled(), field.IsTextPredictionEnabled(),
            names && names.Size() > 0 ? static_cast<int32_t>(names.GetAt(0).NameValue()) : -1,
            static_cast<int32_t>(field.TextAlignment()), field.SelectionStart(), field.SelectionLength(),
            field.PlaceholderForeground() != nullptr, field.AcceptsReturn(),
        };
        std::memcpy(facts, read, sizeof read);
    } catch (...) {
        report("reading a field");
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
    } catch (...) {
        report("typing in a search box");
    }
}

extern "C" void stateui_winui_search_submit_as_user(StateUIObjectRef handle) {
    try {
        // A search box's automation peer submits its query as its own button does.
        pattern<provider::IInvokeProvider>(as<xaml::UIElement>(handle), PatternInterface::Invoke).Invoke();
    } catch (...) {
        report("submitting a search as the user");
    }
}
