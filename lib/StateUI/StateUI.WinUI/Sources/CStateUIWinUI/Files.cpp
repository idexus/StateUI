// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The files the user opens and saves, in Windows' own file dialogs, and what
// Windows launches. A file is read and written beside the UI thread; every
// answer goes back on it, by ticket.
// Design: docs/design/platforms/winui/runtime.md#files

#include "Relay.h"

#include <algorithm>
#include <cctype>
#include <memory>
#include <string>
#include <thread>
#include <vector>

#include <winrt/Microsoft.UI.h>
#include <winrt/Microsoft.UI.Windowing.h>
#include <winrt/Microsoft.Windows.Storage.Pickers.h>
#include <winrt/Windows.Storage.h>
#include <winrt/Windows.System.h>

using namespace stateui;
using winrt::Windows::Foundation::AsyncStatus;
using winrt::Windows::Foundation::IAsyncOperation;
using winrt::Windows::Foundation::Collections::IVectorView;
namespace pickers = winrt::Microsoft::Windows::Storage::Pickers;

namespace {
    /// While a test holds them, a launch is answered as taken and Windows is asked nothing.
    bool launchesHeld = false;

    /// The folder a test keeps its files in, where a dialog that saves opens; empty for the dialog's own.
    std::wstring testFolder;

    /// What a dialog asks for, held past the call that asked: its kind, its kinds of file - each a caption and its
    /// extensions with their dots - a save's name and contents.
    struct Request {
        int32_t kind = 0;
        std::vector<std::pair<winrt::hstring, std::vector<winrt::hstring>>> types;
        winrt::hstring name;
        std::vector<uint8_t> contents;
    };

    Request request(StateUIFileDialog const &dialog) {
        Request asked;
        asked.kind = dialog.kind;
        int32_t next = 0;
        for (int32_t index = 0; index < dialog.typeCount; ++index) {
            std::vector<winrt::hstring> extensions;
            for (int32_t count = 0; count < dialog.extensionCounts[index]; ++count)
                extensions.push_back(L"." + text(dialog.extensions[next++]));
            asked.types.emplace_back(text(dialog.captions[index]), std::move(extensions));
        }
        asked.name = text(dialog.name);
        if (dialog.contents && dialog.length > 0) asked.contents.assign(dialog.contents, dialog.contents + dialog.length);
        return asked;
    }

    /// What a dialog chose - none for a cancel - or why it failed.
    struct Chosen {
        std::vector<std::string> paths;
        std::string failure;
    };

    /// Hands what the dialog under `ticket` chose to the host, on the UI thread: each file by its path and its name.
    void handOver(int64_t ticket, Chosen chosen) {
        runOnUIThread([ticket, chosen = std::move(chosen)] {
            std::vector<std::string> names;
            for (auto const &path : chosen.paths) names.push_back(path.substr(path.find_last_of("\\/") + 1));
            std::vector<char const *> paths, named;
            for (size_t index = 0; index < names.size(); ++index) {
                paths.push_back(chosen.paths[index].c_str());
                named.push_back(names[index].c_str());
            }
            callbacks.filesChosen(ticket, static_cast<int32_t>(paths.size()), paths.data(), named.data(),
                                  chosen.failure.empty() ? nullptr : chosen.failure.c_str());
        });
    }

    /// Why the last call of Windows' failed, after what was being done to which path.
    std::string failed(char const *doing, std::string const &path) {
        auto code = GetLastError();
        wchar_t *message = nullptr;
        FormatMessageW(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
                       nullptr, code, 0, reinterpret_cast<wchar_t *>(&message), 0, nullptr);
        std::string words = message ? winrt::to_string(message) : "error " + std::to_string(code);
        LocalFree(message);
        while (!words.empty() && std::isspace(static_cast<unsigned char>(words.back()))) words.pop_back();
        return std::string(doing) + " " + path + ": " + words;
    }

    /// Writes `bytes` as the whole of the file at `path`: why not, empty where they stand written.
    std::string write(std::string const &path, std::vector<uint8_t> const &bytes) {
        auto file = CreateFileW(winrt::to_hstring(path).c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS,
                                FILE_ATTRIBUTE_NORMAL, nullptr);
        if (file == INVALID_HANDLE_VALUE) return failed("could not write", path);
        std::string why;
        for (size_t done = 0; done < bytes.size() && why.empty();) {
            DWORD wrote = 0;
            auto part = static_cast<DWORD>(std::min<size_t>(bytes.size() - done, 1u << 30));
            if (WriteFile(file, bytes.data() + done, part, &wrote, nullptr)) done += wrote;
            else why = failed("could not write", path);
        }
        CloseHandle(file);
        return why;
    }

    /// The file at `path` into `bytes` - whole for a `maximum` below nought, else its first `maximum` bytes, read
    /// no further; why it failed, or nothing.
    std::string read(std::string const &path, int64_t maximum, std::vector<uint8_t> &bytes) {
        auto file = CreateFileW(winrt::to_hstring(path).c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING,
                                FILE_ATTRIBUTE_NORMAL, nullptr);
        if (file == INVALID_HANDLE_VALUE) return failed("could not read", path);
        std::string why;
        LARGE_INTEGER size{};
        if (GetFileSizeEx(file, &size)) {
            auto whole = static_cast<uint64_t>(size.QuadPart);
            bytes.resize(static_cast<size_t>(maximum < 0 ? whole : std::min<uint64_t>(whole, maximum)));
        }
        else why = failed("could not read", path);
        size_t done = 0;
        while (done < bytes.size() && why.empty()) {
            DWORD got = 0;
            auto part = static_cast<DWORD>(std::min<size_t>(bytes.size() - done, 1u << 30));
            if (!ReadFile(file, bytes.data() + done, part, &got, nullptr)) why = failed("could not read", path);
            else if (got == 0) break;
            done += got;
        }
        bytes.resize(done);
        CloseHandle(file);
        return why;
    }

    /// Why an operation that did not complete failed.
    template <typename Operation>
    std::string failure(Operation const &operation) {
        return "the file dialog failed: " + winrt::to_string(winrt::hresult_error(operation.ErrorCode()).message());
    }

    /// Hands over the file a dialog for one chose; a save's once its contents stand written, beside the UI thread.
    void chosenOne(IAsyncOperation<pickers::PickFileResult> const &picking, int64_t ticket,
                   std::shared_ptr<Request> const &saving) {
        picking.Completed(guarded("handling a file dialog's answer", [ticket, saving](
                IAsyncOperation<pickers::PickFileResult> const &picked, AsyncStatus status) {
            Chosen chosen;
            try {
                if (status != AsyncStatus::Completed) chosen.failure = failure(picked);
                else if (auto result = picked.GetResults()) chosen.paths.push_back(winrt::to_string(result.Path()));
            } catch (...) {
                chosen.failure = "the file dialog failed: 0x" + std::to_string(report("taking a file dialog's answer"));
            }
            if (!saving || chosen.paths.empty()) return handOver(ticket, std::move(chosen));
            std::thread([ticket, saving, chosen = std::move(chosen)]() mutable {
                auto why = write(chosen.paths.front(), saving->contents);
                if (!why.empty()) chosen = {{}, why};
                handOver(ticket, std::move(chosen));
            }).detach();
        }));
    }

    /// Hands over the files a dialog for several chose.
    void chosenSeveral(IAsyncOperation<IVectorView<pickers::PickFileResult>> const &picking, int64_t ticket) {
        picking.Completed(guarded("handling a file dialog's answer", [ticket](
                IAsyncOperation<IVectorView<pickers::PickFileResult>> const &picked, AsyncStatus status) {
            Chosen chosen;
            try {
                if (status != AsyncStatus::Completed) chosen.failure = failure(picked);
                else for (auto const &result : picked.GetResults()) chosen.paths.push_back(winrt::to_string(result.Path()));
            } catch (...) {
                chosen.failure = "the file dialog failed: 0x" + std::to_string(report("taking a file dialog's answer"));
            }
            handOver(ticket, std::move(chosen));
        }));
    }

    /// Tells the host, on the UI thread, whether what was launched under `ticket` was taken.
    void launchAnswer(int64_t ticket, bool taken) {
        runOnUIThread([ticket, taken] { callbacks.launchAnswered(ticket, taken); });
    }
}

extern "C" void stateui_winui_show_file_dialog(StateUIObjectRef handle, int64_t ticket, StateUIFileDialog const *dialog) {
    try {
        auto window = borrow<xaml::Window>(handle).AppWindow().Id();
        auto asked = std::make_shared<Request>(request(*dialog));
        if (asked->kind == 2) {
            pickers::FileSavePicker picker(window);
            if (!asked->name.empty()) picker.SuggestedFileName(asked->name);
            if (!testFolder.empty()) picker.SuggestedFolder(testFolder);
            for (auto const &[caption, extensions] : asked->types) {
                if (!extensions.empty())
                    picker.FileTypeChoices().Insert(
                        caption, winrt::single_threaded_vector<winrt::hstring>(std::vector<winrt::hstring>(extensions)));
            }
            if (!asked->types.empty() && !asked->types.front().second.empty())
                picker.DefaultFileExtension(asked->types.front().second.front());
            return chosenOne(picker.PickSaveFileAsync(), ticket, asked);
        }
        pickers::FileOpenPicker picker(window);
        for (auto const &[caption, extensions] : asked->types) {
            for (auto const &extension : extensions) {
                uint32_t place = 0;
                if (!picker.FileTypeFilter().IndexOf(extension, place)) picker.FileTypeFilter().Append(extension);
            }
        }
        if (asked->kind == 1) return chosenSeveral(picker.PickMultipleFilesAsync(), ticket);
        chosenOne(picker.PickSingleFileAsync(), ticket, nullptr);
    } catch (...) {
        handOver(ticket, {{}, "the file dialog could not be shown: 0x" + std::to_string(report("showing a file dialog"))});
    }
}

extern "C" void stateui_winui_read_file(int64_t ticket, char const *path, int64_t maximum) {
    try {
        std::thread([ticket, maximum, path = std::string(path ? path : "")] {
            auto bytes = std::make_shared<std::vector<uint8_t>>();
            auto why = read(path, maximum, *bytes);
            runOnUIThread([ticket, bytes, why] {
                callbacks.fileRead(
                    ticket, bytes->data(), static_cast<int64_t>(bytes->size()), why.empty() ? nullptr : why.c_str());
            });
        }).detach();
    } catch (...) {
        auto why = "the file could not be read: 0x" + std::to_string(report("reading a file"));
        runOnUIThread([ticket, why] { callbacks.fileRead(ticket, nullptr, 0, why.c_str()); });
    }
}

extern "C" void stateui_winui_launch(int64_t ticket, char const *target, bool file) {
    auto named = std::string(target ? target : "");
    launched(named);
    if (launchesHeld) return launchAnswer(ticket, true);
    try {
        using winrt::Windows::System::Launcher;
        if (!file) {
            Launcher::LaunchUriAsync(winrt::Windows::Foundation::Uri(winrt::to_hstring(named)))
                .Completed(guarded("handling a launch's answer", [ticket](IAsyncOperation<bool> const &launching,
                                                                         AsyncStatus status) {
                    launchAnswer(ticket, status == AsyncStatus::Completed && launching.GetResults());
                }));
            return;
        }
        using winrt::Windows::Storage::StorageFile;
        StorageFile::GetFileFromPathAsync(winrt::to_hstring(named))
            .Completed(guarded("handling a launched file", [ticket](IAsyncOperation<StorageFile> const &found,
                                                                   AsyncStatus status) {
                try {
                    if (status != AsyncStatus::Completed) return launchAnswer(ticket, false);
                    Launcher::LaunchFileAsync(found.GetResults())
                        .Completed(guarded("handling a launch's answer", [ticket](
                                IAsyncOperation<bool> const &launching, AsyncStatus status) {
                            launchAnswer(ticket, status == AsyncStatus::Completed && launching.GetResults());
                        }));
                } catch (...) {
                    report("launching a file");
                    launchAnswer(ticket, false);
                }
            }));
    } catch (...) {
        report("launching");
        launchAnswer(ticket, false);
    }
}

extern "C" void stateui_winui_hold_launches(bool held) {
    try {
        launchesHeld = held;
    } catch (...) {
        report("holding launches");
    }
}

extern "C" void stateui_winui_keep_test_files_in(char const *folder) {
    try {
        testFolder = text(folder);
    } catch (...) {
        report("keeping a test's files");
    }
}

namespace stateui {
    HWND fileNameField(HWND dialog) {
        // The edit standing in the dialog's control of the file's name: cmb13 (1148) where it opens, 1001 where it
        // saves.
        struct Search {
            HWND dialog;
            HWND found;
        } search{dialog, nullptr};
        EnumChildWindows(dialog, [](HWND child, LPARAM given) -> BOOL {
            auto &search = *reinterpret_cast<Search *>(given);
            wchar_t kind[16] = {};
            GetClassNameW(child, kind, 16);
            if (std::wstring_view(kind) != L"Edit") return TRUE;
            for (auto up = child; up && up != search.dialog; up = GetParent(up)) {
                auto id = GetDlgCtrlID(up);
                if (id == 1148 || id == 1001) {
                    search.found = child;
                    return FALSE;
                }
            }
            return TRUE;
        }, reinterpret_cast<LPARAM>(&search));
        return search.found;
    }

    HWND fileDialog() {
        HWND found = nullptr;
        EnumWindows([](HWND window, LPARAM given) -> BOOL {
            DWORD process = 0;
            GetWindowThreadProcessId(window, &process);
            wchar_t kind[16] = {};
            GetClassNameW(window, kind, 16);
            if (process != GetCurrentProcessId() || !IsWindowVisible(window) || std::wstring_view(kind) != L"#32770")
                return TRUE;
            if (!fileNameField(window)) return TRUE;
            *reinterpret_cast<HWND *>(given) = window;
            return FALSE;
        }, reinterpret_cast<LPARAM>(&found));
        return found;
    }
}

namespace {
    /// The words a window of another thread holds.
    std::wstring words(HWND window) {
        std::wstring held(static_cast<size_t>(SendMessageW(window, WM_GETTEXTLENGTH, 0, 0)) + 1, L'\0');
        held.resize(static_cast<size_t>(
            SendMessageW(window, WM_GETTEXT, held.size(), reinterpret_cast<LPARAM>(held.data()))));
        return held;
    }
}

extern "C" int64_t stateui_winui_answer_file_dialog(int64_t given, char const *const *paths, int32_t count) {
    try {
        auto dialog = given ? reinterpret_cast<HWND>(given) : fileDialog();
        if (!dialog || !IsWindow(dialog) || !IsWindowVisible(dialog)) return 0;
        auto button = count == 0 ? IDCANCEL : IDOK;
        // The paths typed whole, and the names alone: what a dialog that opens leaves in its field once it has gone
        // to their folder, and takes at the next press.
        std::wstring typed, named;
        for (int32_t index = 0; index < count; ++index) {
            std::wstring path(text(paths[index]));
            auto name = path.substr(path.find_last_of(L"\\/") + 1);
            typed += count == 1 ? path : L"\"" + path + L"\" ";
            named += count == 1 ? name : L"\"" + name + L"\" ";
        }
        auto field = fileNameField(dialog);
        auto trimmed = [](std::wstring words) {
            while (!words.empty() && words.back() == L' ') words.pop_back();
            return words;
        };
        auto holds = [&] {
            auto held = trimmed(field ? words(field) : L"");
            return held == trimmed(typed) || held == trimmed(named);
        };
        // Typed as the keyboard types, a letter at a time over what the field held: words set into the field of the
        // dialog that saves (`WM_SETTEXT`) show, and Save saves the dialog's own name in its own folder.
        if (count > 0 && field && !holds()) {
            SendMessageW(field, EM_SETSEL, 0, -1);
            for (auto letter : typed) SendMessageW(field, WM_CHAR, letter, 0);
        }
        // A dialog standing behind a question of its own - a file that exists - takes no press.
        if (IsWindowEnabled(dialog) && (count == 0 || holds()))
            PostMessageW(dialog, WM_COMMAND, MAKEWPARAM(button, BN_CLICKED), reinterpret_cast<LPARAM>(GetDlgItem(dialog, button)));
        return reinterpret_cast<int64_t>(dialog);
    } catch (...) {
        report("answering a file dialog");
        return 0;
    }
}
