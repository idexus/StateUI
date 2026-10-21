// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import android.os.Handler;
import android.os.Looper;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.CookieHandler;
import java.net.CookieManager;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * The requests the application sends: the platform's own HTTP connection, beside the UI thread - the system's
 * certificates, proxy and network rules hold - the cookies a server sets kept for the process.
 */
final class StateUIRequests {
    private static final Handler ui = new Handler(Looper.getMainLooper());
    private static final ExecutorService senders = Executors.newCachedThreadPool();
    /** Each request's connection under way, and the requests stopped, by ticket. */
    private static final Map<Long, HttpURLConnection> underWay = new ConcurrentHashMap<>();
    private static final Set<Long> stopped = ConcurrentHashMap.newKeySet();

    private StateUIRequests() {}

    /**
     * Sends a request - its headers as names and values in turn - and answers the status, the headers the same way
     * and the body, or why no answer came.
     */
    static void send(long ticket, String address, String method, String[] headers, byte[] body) {
        if (CookieHandler.getDefault() == null) CookieHandler.setDefault(new CookieManager());
        senders.execute(() -> {
            int status = 0;
            List<String> said = new ArrayList<>();
            byte[] read = new byte[0];
            String failure = null;
            HttpURLConnection connection = null;
            try {
                connection = (HttpURLConnection) new URL(address).openConnection();
                underWay.put(ticket, connection);
                if (stopped.contains(ticket)) throw new java.io.IOException("the request was stopped");
                connection.setRequestMethod(method);
                for (int index = 0; index + 1 < headers.length; index += 2) {
                    connection.addRequestProperty(headers[index], headers[index + 1]);
                }
                if (body.length > 0) {
                    connection.setDoOutput(true);
                    connection.setFixedLengthStreamingMode(body.length);
                    try (OutputStream out = connection.getOutputStream()) {
                        out.write(body);
                    }
                }
                status = connection.getResponseCode();
                for (Map.Entry<String, List<String>> header : connection.getHeaderFields().entrySet()) {
                    if (header.getKey() == null) continue;
                    for (String value : header.getValue()) {
                        said.add(header.getKey());
                        said.add(value);
                    }
                }
                InputStream stream = status >= 400 ? connection.getErrorStream() : connection.getInputStream();
                if (stream != null) {
                    try (InputStream in = stream) {
                        read = all(in);
                    }
                }
            } catch (Exception failed) {
                failure = failed.getMessage() != null ? failed.getMessage() : failed.toString();
            } finally {
                underWay.remove(ticket);
                stopped.remove(ticket);
                if (connection != null) connection.disconnect();
            }
            int answered = status;
            String[] names = said.toArray(new String[0]);
            byte[] bytes = read;
            String why = failure;
            ui.post(() -> StateUIHost.requestAnswered(ticket, answered, names, bytes, why));
        });
    }

    /** Stops the request under `ticket`: its connection closed, or never opened. */
    static void cancel(long ticket) {
        stopped.add(ticket);
        HttpURLConnection connection = underWay.remove(ticket);
        if (connection != null) senders.execute(connection::disconnect);
    }

    private static byte[] all(InputStream in) throws java.io.IOException {
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        byte[] run = new byte[64 * 1024];
        for (int count; (count = in.read(run)) > 0; ) bytes.write(run, 0, count);
        return bytes.toByteArray();
    }
}
