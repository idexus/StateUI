// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The requests the application sends, through Windows' own HTTP client: the
// system's certificates, proxy and cookies hold. Every answer goes back on the
// UI thread, by ticket.
// Design: docs/design/core/acts.md#requests

#include "Relay.h"

#include <cctype>
#include <map>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

#include <winrt/Windows.Storage.Streams.h>
#include <winrt/Windows.Web.Http.h>
#include <winrt/Windows.Web.Http.Headers.h>

using namespace stateui;
using winrt::Windows::Foundation::AsyncStatus;
using winrt::Windows::Foundation::IAsyncOperationWithProgress;
namespace http = winrt::Windows::Web::Http;
namespace streams = winrt::Windows::Storage::Streams;

namespace {
    /// The client every request goes through, keeping the cookies a server sets for the process.
    http::HttpClient &client() {
        static http::HttpClient shared;
        return shared;
    }

    /// Each request under way, by its ticket: what stops it.
    std::mutex underWayLock;
    std::map<int64_t, IAsyncOperationWithProgress<http::HttpResponseMessage, http::HttpProgress>> underWay;

    /// The request under `ticket` is under way no more.
    void ended(int64_t ticket) {
        std::lock_guard held(underWayLock);
        underWay.erase(ticket);
    }

    /// Answers the request under `ticket` on the UI thread.
    void answer(int64_t ticket, int32_t status, std::string headers, std::vector<uint8_t> body, std::string failure) {
        auto held = std::make_shared<std::tuple<std::string, std::vector<uint8_t>, std::string>>(
            std::move(headers), std::move(body), std::move(failure));
        runOnUIThread([ticket, status, held] {
            auto &[said, bytes, why] = *held;
            callbacks.requestAnswered(
                ticket, status, said.c_str(), bytes.data(), static_cast<int64_t>(bytes.size()),
                why.empty() ? nullptr : why.c_str());
        });
    }

    /// Why a request failed, in the system's words.
    std::string failure(winrt::hresult code) {
        return winrt::to_string(winrt::hresult_error(code).message());
    }

    /// Each header of `headers` as a name and a value, a unit separator before each.
    template <typename Headers>
    void write(Headers const &headers, std::string &into) {
        for (auto const &header : headers) {
            if (!into.empty()) into += '\x1F';
            into += winrt::to_string(header.Key()) + '\x1F' + winrt::to_string(header.Value());
        }
    }
}

extern "C" void stateui_winui_send_request(
    int64_t ticket, char const *address, char const *method, char const *headers, uint8_t const *body, int64_t length) {
    try {
        http::HttpRequestMessage message(
            http::HttpMethod(winrt::to_hstring(method ? method : "GET")),
            winrt::Windows::Foundation::Uri(winrt::to_hstring(address ? address : "")));
        if (length > 0) {
            streams::DataWriter writer;
            writer.WriteBytes(winrt::array_view<uint8_t const>(body, body + length));
            message.Content(http::HttpBufferContent(writer.DetachBuffer()));
        }
        std::vector<std::string> named;
        std::string said = headers ? headers : "";
        for (size_t start = 0, end; start <= said.size(); start = end + 1) {
            end = said.find('\x1F', start);
            if (end == std::string::npos) end = said.size();
            named.push_back(said.substr(start, end - start));
        }
        for (size_t index = 0; index + 1 < named.size(); index += 2) {
            auto name = winrt::to_hstring(named[index]), value = winrt::to_hstring(named[index + 1]);
            std::string lower = named[index];
            for (auto &letter : lower) letter = static_cast<char>(std::tolower(static_cast<unsigned char>(letter)));
            // A header of the body stands with the body; the request's own refuse it.
            if (lower.rfind("content-", 0) == 0) {
                if (message.Content()) message.Content().Headers().TryAppendWithoutValidation(name, value);
            } else {
                message.Headers().TryAppendWithoutValidation(name, value);
            }
        }
        auto sending = client().SendRequestAsync(message);
        {
            std::lock_guard held(underWayLock);
            underWay.emplace(ticket, sending);
        }
        sending.Completed(guarded("handling a request's answer", [ticket](
                IAsyncOperationWithProgress<http::HttpResponseMessage, http::HttpProgress> const &sending,
                AsyncStatus status) {
            ended(ticket);
            if (status == AsyncStatus::Canceled) return answer(ticket, 0, "", {}, "the request was stopped");
            if (status != AsyncStatus::Completed) return answer(ticket, 0, "", {}, failure(sending.ErrorCode()));
            auto response = sending.GetResults();
            auto code = static_cast<int32_t>(response.StatusCode());
            std::string said;
            write(response.Headers(), said);
            write(response.Content().Headers(), said);
            response.Content().ReadAsBufferAsync().Completed(guarded("reading a request's answer", [
                    ticket, code, said](auto const &reading, AsyncStatus status) {
                if (status != AsyncStatus::Completed) return answer(ticket, 0, "", {}, failure(reading.ErrorCode()));
                auto buffer = reading.GetResults();
                answer(ticket, code, said, std::vector<uint8_t>(buffer.data(), buffer.data() + buffer.Length()), "");
            }));
        }));
    } catch (...) {
        auto code = report("sending a request");
        answer(ticket, 0, "", {}, "the request could not be sent: 0x" + std::to_string(code));
    }
}

extern "C" void stateui_winui_cancel_request(int64_t ticket) {
    try {
        IAsyncOperationWithProgress<http::HttpResponseMessage, http::HttpProgress> sending{nullptr};
        {
            std::lock_guard held(underWayLock);
            auto found = underWay.find(ticket);
            if (found == underWay.end()) return;
            sending = found->second;
            underWay.erase(found);
        }
        sending.Cancel();
    } catch (...) {
        report("stopping a request");
    }
}
