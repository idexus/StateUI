// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Pictures from the application's own folder: an Image showing one by file
// name, an SVG found under the PNG name it is asked for, at the size it
// declares, drawn at the size it shows at.
// Design: docs/design/platforms/winui/controls.md#pictures

#include "Relay.h"

#include <algorithm>
#include <cctype>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <string>

#include <shcore.h>
#include <shlwapi.h>

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Storage.Streams.h>
#include <winrt/Microsoft.UI.Xaml.Media.Imaging.h>

using namespace stateui;
namespace imaging = winrt::Microsoft::UI::Xaml::Media::Imaging;

namespace {
    /// The folder pictures are read from; empty for `Images` beside the executable.
    std::wstring folder;

    std::wstring pictures() {
        if (!folder.empty()) return folder;
        wchar_t path[MAX_PATH] = {};
        GetModuleFileNameW(nullptr, path, MAX_PATH);
        std::wstring executable(path);
        return executable.substr(0, executable.find_last_of(L"\\/") + 1) + L"Images\\";
    }

    bool exists(std::wstring const &path) {
        auto attributes = GetFileAttributesW(path.c_str());
        return attributes != INVALID_FILE_ATTRIBUTES && !(attributes & FILE_ATTRIBUTE_DIRECTORY);
    }

    winrt::Windows::Foundation::Uri address(std::wstring path) {
        for (auto &character : path) if (character == L'\\') character = L'/';
        return winrt::Windows::Foundation::Uri(L"file:///" + path);
    }

    /// Where attribute `name`'s value begins in an SVG's opening tag; npos for none.
    size_t attribute(std::string const &tag, std::string const &name) {
        for (auto at = tag.find(name); at != std::string::npos; at = tag.find(name, at + 1)) {
            if (at == 0 || !std::isspace(static_cast<unsigned char>(tag[at - 1]))) continue;
            auto next = tag.find_first_not_of(" \t\r\n", at + name.size());
            if (next == std::string::npos || tag[next] != '=') continue;
            next = tag.find_first_not_of(" \t\r\n", next + 1);
            if (next != std::string::npos && (tag[next] == '"' || tag[next] == '\'')) return next + 1;
        }
        return std::string::npos;
    }

    /// A length an SVG gives its picture, in DIPs; 0 for none, and for a share of a room it does not know.
    double length(std::string const &tag, std::string const &name) {
        auto at = attribute(tag, name);
        if (at == std::string::npos) return 0;
        char *end = nullptr;
        auto number = std::strtod(tag.c_str() + at, &end);
        std::string unit(end, std::strcspn(end, "\"' \t"));
        if (unit.empty() || unit == "px") return number;
        if (unit == "pt") return number * 96 / 72;
        if (unit == "pc") return number * 16;
        if (unit == "in") return number * 96;
        if (unit == "cm") return number * 96 / 2.54;
        if (unit == "mm") return number * 96 / 25.4;
        return 0;
    }

    /// Where an SVG's opening tag stands in its text, and how long it is; npos for none.
    std::pair<size_t, size_t> root(std::string const &text) {
        auto start = text.find("<svg");
        if (start == std::string::npos) return {start, 0};
        return {start, std::min(text.find('>', start), text.size()) - start};
    }

    /// The size an SVG declares, in DIPs: its width and height, the one missing taken from its viewBox's
    /// proportions, or its viewBox's; zero where it declares none.
    winrt::Windows::Foundation::Size declared(std::string const &text) {
        auto [start, span] = root(text);
        if (start == std::string::npos) return {};
        auto tag = text.substr(start, span);
        double width = length(tag, "width"), height = length(tag, "height");
        double box[4] = {};
        if (auto at = attribute(tag, "viewBox"); at != std::string::npos) {
            char const *cursor = tag.c_str() + at;
            for (auto &number : box) {
                char *end = nullptr;
                number = std::strtod(cursor, &end);
                cursor = end + std::strspn(end, ", \t\r\n");
            }
        }
        if (box[2] > 0 && box[3] > 0) {
            if (width <= 0 && height <= 0) width = box[2], height = box[3];
            else if (width <= 0) width = height * box[2] / box[3];
            else if (height <= 0) height = width * box[3] / box[2];
        }
        if (width <= 0 || height <= 0) return {};
        return {static_cast<float>(width), static_cast<float>(height)};
    }

    /// Makes the picture `text` draws give up its proportions, filling whatever room it is drawn in.
    void letGoOfProportions(std::string &text) {
        auto [start, span] = root(text);
        if (start == std::string::npos) return;
        auto tag = text.substr(start, span);
        if (auto at = attribute(tag, "preserveAspectRatio"); at != std::string::npos)
            text.replace(start + at, tag.find(tag[at - 1], at) - at, "none");
        else
            text.insert(start + 4, " preserveAspectRatio=\"none\"");
    }

    std::string contents(std::wstring const &path) {
        std::string text;
        FILE *file = nullptr;
        if (_wfopen_s(&file, path.c_str(), L"rb") != 0 || !file) return text;
        char buffer[16384];
        for (size_t read; (read = std::fread(buffer, 1, sizeof buffer, file)) > 0;) text.append(buffer, read);
        std::fclose(file);
        return text;
    }

    /// An SVG source drawing `text`, read from memory.
    imaging::SvgImageSource drawing(std::string const &text) {
        winrt::com_ptr<IStream> memory;
        memory.attach(SHCreateMemStream(reinterpret_cast<BYTE const *>(text.data()), static_cast<UINT>(text.size())));
        if (!memory) winrt::throw_hresult(E_OUTOFMEMORY);
        winrt::Windows::Storage::Streams::IRandomAccessStream stream{nullptr};
        winrt::check_hresult(CreateRandomAccessStreamOverStream(
            memory.get(), BSOS_DEFAULT, winrt::guid_of<decltype(stream)>(), winrt::put_abi(stream)));
        imaging::SvgImageSource source;
        source.SetSourceAsync(stream);
        return source;
    }
}

extern "C" void stateui_winui_set_pictures(char const *utf8) {
    folder = winrt::to_hstring(std::string_view(utf8 ? utf8 : "")).c_str();
    if (!folder.empty() && folder.back() != L'\\' && folder.back() != L'/') folder += L'\\';
}

extern "C" StateUIObjectRef stateui_winui_image_make(void) {
    try {
        return detach(controls::Image());
    } catch (winrt::hresult_error const &error) {
        report(error, "making an image");
        return nullptr;
    }
}

extern "C" bool stateui_winui_image_set(
    StateUIObjectRef handle, char const *const *names, int32_t count, int32_t aspect, double *size
) {
    size[0] = size[1] = 0;
    try {
        auto image = borrow<controls::Image>(handle);
        // StateUI's Aspect: fit, fill, stretch, centre - at the picture's own size, in the middle of the room.
        auto centred = aspect == 3;
        image.Stretch(aspect == 1 ? xaml::Media::Stretch::UniformToFill
                      : aspect == 2 ? xaml::Media::Stretch::Fill
                      : centred ? xaml::Media::Stretch::None : xaml::Media::Stretch::Uniform);
        image.HorizontalAlignment(centred ? xaml::HorizontalAlignment::Center : xaml::HorizontalAlignment::Stretch);
        image.VerticalAlignment(centred ? xaml::VerticalAlignment::Center : xaml::VerticalAlignment::Stretch);
        image.ClearValue(xaml::FrameworkElement::WidthProperty());
        image.ClearValue(xaml::FrameworkElement::HeightProperty());

        // The first of the files the name stands for that the pictures hold.
        std::wstring file;
        for (int32_t index = 0; index < count && file.empty(); ++index) {
            std::wstring each(winrt::to_hstring(std::string_view(names[index] ? names[index] : "")).c_str());
            if (!each.empty() && exists(pictures() + each)) file = each;
        }
        auto named = count > 0 && names[0] && *names[0];
        if (file.empty()) {
            image.Source(nullptr);
            return !named;
        }
        auto path = pictures() + file;
        auto dot = file.find_last_of(L'.');
        auto extension = dot == std::wstring::npos ? std::wstring() : file.substr(dot);
        if (extension != L".svg") {
            // A bitmap's size is known once it is read; the layout holding it measures it again then.
            imaging::BitmapImage bitmap(address(path));
            bitmap.ImageOpened([held = winrt::make_weak(image)](auto const &, xaml::RoutedEventArgs const &) {
                auto image = held.get();
                if (!image) return;
                if (auto layout = xaml::Media::VisualTreeHelper::GetParent(image).try_as<xaml::UIElement>())
                    layout.InvalidateMeasure();
            });
            image.Source(bitmap);
            return true;
        }

        auto text = contents(path);
        auto own = declared(text);
        size[0] = own.Width;
        size[1] = own.Height;
        if (aspect == 2) letGoOfProportions(text);
        // WinUI takes an SVG's pixels for DIPs: centred, it is drawn at its own size by the image's.
        if (centred && own.Width > 0) {
            image.Stretch(xaml::Media::Stretch::Uniform);
            image.Width(own.Width);
            image.Height(own.Height);
        }
        image.Source(drawing(text));
        return true;
    } catch (winrt::hresult_error const &error) {
        report(error, "showing a picture");
        return false;
    }
}

extern "C" void stateui_winui_image_size(StateUIObjectRef handle, double *size) {
    size[0] = size[1] = 0;
    try {
        auto bitmap = borrow<controls::Image>(handle).Source().try_as<imaging::BitmapImage>();
        if (!bitmap) return;
        size[0] = bitmap.PixelWidth();
        size[1] = bitmap.PixelHeight();
    } catch (winrt::hresult_error const &error) {
        report(error, "reading a picture's size");
    }
}

extern "C" void stateui_winui_image_draw(StateUIObjectRef handle, double width, double height) {
    try {
        auto image = borrow<controls::Image>(handle);
        auto drawn = image.Source().try_as<imaging::SvgImageSource>();
        if (!drawn) return;
        auto scale = image.XamlRoot() ? image.XamlRoot().RasterizationScale() : 1.0;
        drawn.RasterizePixelWidth(std::ceil(width * scale));
        drawn.RasterizePixelHeight(std::ceil(height * scale));
    } catch (winrt::hresult_error const &error) {
        report(error, "drawing a picture");
    }
}
