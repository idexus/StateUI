// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A question for the user in WinUI's own dialog - an alert, a confirmation, a
// choice of actions, a prompt - its answer handed back by ticket. The host
// asks one at a time: the next once this one is answered.
// Design: docs/design/platforms/winui/runtime.md#questions-for-the-user

#include "Relay.h"

#include <functional>
#include <memory>
#include <string>
#include <vector>

#include <winrt/Microsoft.UI.Xaml.Automation.Peers.h>
#include <winrt/Microsoft.UI.Xaml.Automation.Provider.h>
#include <winrt/Microsoft.UI.Xaml.Input.h>

using namespace stateui;
using winrt::Windows::Foundation::AsyncStatus;
using winrt::Windows::Foundation::IAsyncOperation;
namespace input = winrt::Microsoft::UI::Xaml::Input;
namespace peers = winrt::Microsoft::UI::Xaml::Automation::Peers;
namespace provider = winrt::Microsoft::UI::Xaml::Automation::Provider;

namespace {
    void answer(int64_t ticket, bool accepted, std::string const &words, bool hasWords) {
        callbacks.answered(ticket, accepted, hasWords ? words.c_str() : nullptr, nullptr);
    }

    /// The question under `ticket` could not be asked: the reason, from the error being handled, is its answer.
    void failed(int64_t ticket, char const *doing) {
        auto reason = std::string("WinUI could not show the question: ") + doing;
        try {
            throw;
        } catch (winrt::hresult_error const &error) {
            reason = "WinUI could not show the question: " + winrt::to_string(error.message());
        } catch (...) {
        }
        report(doing);
        callbacks.answered(ticket, false, nullptr, reason.c_str());
    }

    /// Shows `dialog`, handing its result to `closed` once it closes; a dialog WinUI failed fails its question.
    void show(int64_t ticket, controls::ContentDialog const &dialog,
              std::function<void(controls::ContentDialogResult)> closed) {
        dialog.ShowAsync().Completed(
            guarded("handling Completed",
                [ticket, closed](IAsyncOperation<controls::ContentDialogResult> const &operation, AsyncStatus status) {
                if (status == AsyncStatus::Error) {
                    auto reason = "WinUI could not show the question: "
                        + winrt::to_string(winrt::hresult_error(operation.ErrorCode()).message());
                    return callbacks.answered(ticket, false, nullptr, reason.c_str());
                }
                closed(status == AsyncStatus::Completed ? operation.GetResults() : controls::ContentDialogResult::None);
            }));
    }

    /// Words as a text block that wraps.
    controls::TextBlock paragraph(char const *words) {
        controls::TextBlock block;
        block.Text(text(words));
        block.TextWrapping(xaml::TextWrapping::Wrap);
        return block;
    }

    /// A dialog made for the question under `ticket`, and what hands its answer back once it closes.
    struct Asked {
        int64_t ticket;
        controls::ContentDialog dialog;
        std::function<void(controls::ContentDialogResult)> closed;

        /// Shows the dialog over `root`'s window.
        void show(xaml::XamlRoot const &root) const {
            dialog.XamlRoot(root);
            ::show(ticket, dialog, closed);
        }
    };

    Asked ask(int64_t ticket, StateUIQuestion const &question) {
        controls::ContentDialog dialog;
        std::function<void(controls::ContentDialogResult)> closed;
        dialog.Title(winrt::box_value(text(question.title)));
        auto hasMessage = question.message && *question.message;

        switch (question.kind) {
        case StateUIQuestionKindAlert:
            if (hasMessage) dialog.Content(paragraph(question.message));
            dialog.CloseButtonText(text(question.accept));
            dialog.DefaultButton(controls::ContentDialogButton::Close);
            closed = [ticket](auto) { answer(ticket, true, {}, false); };
            break;
        case StateUIQuestionKindConfirm:
            if (hasMessage) dialog.Content(paragraph(question.message));
            dialog.PrimaryButtonText(text(question.accept));
            dialog.CloseButtonText(text(question.cancel));
            dialog.DefaultButton(controls::ContentDialogButton::Primary);
            closed = [ticket](auto result) {
                answer(ticket, result == controls::ContentDialogResult::Primary, {}, false);
            };
            break;
        case StateUIQuestionKindChooseAction: {
            // A choice is a button of its own, the dangerous one first; the answer is the caption pressed.
            auto chosen = std::make_shared<std::string>();
            auto pressed = std::make_shared<bool>(false);
            controls::StackPanel choices;
            choices.Spacing(8);
            std::vector<std::string> captions;
            if (question.destruction) captions.push_back(question.destruction);
            for (int32_t index = 0; index < question.choiceCount; ++index) captions.push_back(question.choices[index]);
            for (auto const &caption : captions) {
                controls::Button button;
                button.Content(winrt::box_value(winrt::to_hstring(caption)));
                button.HorizontalAlignment(xaml::HorizontalAlignment::Stretch);
                button.Click(guarded("handling Click",
                    [dialog, chosen, pressed, caption](IInspectable const &, xaml::RoutedEventArgs const &) {
                    *chosen = caption;
                    *pressed = true;
                    dialog.Hide();
                }));
                choices.Children().Append(button);
            }
            dialog.Content(choices);
            if (question.cancel) {
                auto cancel = std::string(question.cancel);
                dialog.CloseButtonText(text(question.cancel));
                dialog.CloseButtonClick(guarded("handling CloseButtonClick",
                    [chosen, pressed, cancel](auto const &, auto const &) {
                    *chosen = cancel;
                    *pressed = true;
                }));
            }
            closed = [ticket, chosen, pressed](auto) { answer(ticket, *pressed, *chosen, *pressed); };
            break;
        }
        case StateUIQuestionKindPrompt: {
            controls::StackPanel content;
            content.Spacing(12);
            if (hasMessage) content.Children().Append(paragraph(question.message));
            controls::TextBox field;
            if (question.placeholder) field.PlaceholderText(text(question.placeholder));
            // The words are held within the prompt's bound in characters by the host: WinUI's MaxLength counts
            // UTF-16 units. Each change is told, whether an input method composes them, and again as it commits.
            auto composing = std::make_shared<bool>(false);
            field.TextChanging(guarded("handling a prompt's TextChanging",
                [ticket, composing](controls::TextBox const &sender, controls::TextBoxTextChangingEventArgs const &args) {
                if (!args.IsContentChanging()) return;
                callbacks.promptTyped(ticket, winrt::to_string(sender.Text()).c_str(), *composing);
            }));
            field.TextCompositionStarted(guarded("handling a prompt's TextCompositionStarted",
                [composing](controls::TextBox const &, controls::TextCompositionStartedEventArgs const &) {
                *composing = true;
            }));
            field.TextCompositionEnded(guarded("handling a prompt's TextCompositionEnded",
                [ticket, composing](controls::TextBox const &sender, controls::TextCompositionEndedEventArgs const &) {
                *composing = false;
                callbacks.promptTyped(ticket, winrt::to_string(sender.Text()).c_str(), false);
            }));
            field.IsSpellCheckEnabled(question.spellChecked);
            field.IsTextPredictionEnabled(question.predicted);
            field.InputScope(inputScope(question.scope));
            field.Text(text(question.initial));
            content.Children().Append(field);
            dialog.Content(content);
            dialog.PrimaryButtonText(text(question.accept));
            dialog.CloseButtonText(text(question.cancel));
            dialog.DefaultButton(controls::ContentDialogButton::Primary);
            closed = [ticket, field](auto result) {
                auto accepted = result == controls::ContentDialogResult::Primary;
                answer(ticket, accepted, winrt::to_string(field.Text()), accepted);
            };
        }
        }
        return {ticket, dialog, closed};
    }

    /// The dialog showing over `root`'s window; null for none.
    controls::ContentDialog shown(xaml::XamlRoot const &root) {
        for (auto const &popup : xaml::Media::VisualTreeHelper::GetOpenPopupsForXamlRoot(root))
            if (auto dialog = popup.Child().try_as<controls::ContentDialog>()) return dialog;
        return nullptr;
    }

    /// The field of the prompt `dialog` shows, as its content holds it - loaded or not; null for none.
    controls::TextBox promptField(controls::ContentDialog const &dialog) {
        if (auto panel = dialog.Content().try_as<controls::StackPanel>())
            for (auto const &child : panel.Children())
                if (auto field = child.try_as<controls::TextBox>()) return field;
        return nullptr;
    }
}

namespace stateui {
    xaml::Input::InputScope inputScope(int32_t number) {
        using name = input::InputScopeNameValue;
        auto named = name::Default;
        switch (static_cast<StateUIInputScope>(number)) {
        case StateUIInputScopeDefault: named = name::Default; break;
        case StateUIInputScopeText: named = name::Text; break;
        case StateUIInputScopeChat: named = name::Chat; break;
        case StateUIInputScopeEmail: named = name::EmailSmtpAddress; break;
        case StateUIInputScopeNumber: named = name::Number; break;
        case StateUIInputScopeTelephone: named = name::TelephoneNumber; break;
        case StateUIInputScopeUrl: named = name::Url; break;
        }
        input::InputScope scope;
        input::InputScopeName scopeName;
        scopeName.NameValue(named);
        scope.Names().Append(scopeName);
        return scope;
    }
}

extern "C" void stateui_winui_ask(StateUIObjectRef handle, int64_t ticket, StateUIQuestion const *question) {
    try {
        auto element = as<xaml::FrameworkElement>(handle);
        auto asked = ask(ticket, *question);
        if (auto root = element.XamlRoot()) return asked.show(root);
        // A window opened a moment ago is not loaded yet: the question stands over it once it is.
        // Design: docs/design/platforms/winui/runtime.md#questions-for-the-user
        auto token = std::make_shared<winrt::event_token>();
        *token = element.Loaded(guarded("handling Loaded",
            [asked, token](IInspectable const &sender, xaml::RoutedEventArgs const &) {
            auto loaded = sender.as<xaml::FrameworkElement>();
            loaded.Loaded(*token);
            try {
                asked.show(loaded.XamlRoot());
            } catch (...) {
                failed(asked.ticket, "asking the user");
            }
        }));
    } catch (...) {
        failed(ticket, "asking the user");
    }
}

extern "C" void stateui_winui_prompt_write(StateUIObjectRef handle, char const *words) {
    try {
        auto dialog = shown(as<xaml::UIElement>(handle).XamlRoot());
        auto field = dialog ? promptField(dialog) : nullptr;
        if (!field) return;
        auto written = text(words);
        field.Text(written);
        field.Select(static_cast<int32_t>(written.size()), 0);
    } catch (...) {
        report("writing a prompt's words");
    }
}

extern "C" bool stateui_winui_answer(StateUIObjectRef handle, int32_t button, char const *words) {
    try {
        auto dialog = shown(as<xaml::UIElement>(handle).XamlRoot());
        if (!dialog) return false;
        if (words) {
            if (auto field = promptField(dialog)) field.Text(text(words));
        }
        controls::Button pressed{nullptr};
        if (button < 2) {
            pressed = first<controls::Button>(dialog, button == 0 ? L"PrimaryButton" : L"CloseButton");
        } else if (auto choices = dialog.Content().try_as<controls::StackPanel>()) {
            auto index = static_cast<uint32_t>(button - 2);
            if (index < choices.Children().Size()) pressed = choices.Children().GetAt(index).try_as<controls::Button>();
        }
        // A button the dialog does not show has no peer.
        auto peer = pressed ? peers::FrameworkElementAutomationPeer::CreatePeerForElement(pressed) : nullptr;
        if (!peer) return false;
        peer.GetPattern(peers::PatternInterface::Invoke).as<provider::IInvokeProvider>().Invoke();
        return true;
    } catch (...) {
        report("answering a dialog");
        return false;
    }
}
