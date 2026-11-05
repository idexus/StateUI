// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

package stateui.android;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLConnection;
import java.net.URLStreamHandler;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.locks.LockSupport;

/** The real request relay over an in-memory connection; the UI thread holds its answer while the worker ends. */
public final class TestRequests {
    private static final Map<String, Connection> connections = new ConcurrentHashMap<>();
    private static final String installation = install();
    private static long nextTicket = -1;
    private static long latestTicket;

    private TestRequests() {}

    private static String install() {
        try {
            URL.setURLStreamHandlerFactory(protocol -> protocol.equals("stateui-request-test") ? new URLStreamHandler() {
                @Override protected URLConnection openConnection(URL address) throws IOException {
                    Connection connection = connections.get(address.toExternalForm());
                    if (connection == null) throw new IOException("the test connection is gone");
                    connection.opening.countDown();
                    await(connection.mayOpen, "connection opening");
                    if (connection.refuses.get()) throw new IOException("the test connection refused to open");
                    return connection;
                }
            } : null);
            return "";
        } catch (Error failure) {
            return failure.toString();
        }
    }

    public static String completed() {
        return run(false, false, connection -> {
            finished(connection);
            require(connection.reads.get() == 1, "the request read its response");
            require(connection.closes.get() == 1, "completion releases its connection once");
        });
    }

    public static String cancelledBeforeConnection() {
        return run(true, false, connection -> {
            await(connection.opening, "worker before connection attachment");
            require(StateUIRequests.waitingForTesting() == 1, "the request stands before it has a connection");
            StateUIRequests.cancel(latestTicket);
            StateUIRequests.cancel(latestTicket);
            connection.mayOpen.countDown();
            finished(connection);
            require(connection.reads.get() == 0, "a cancelled request starts no I/O");
            require(connection.closes.get() == 1, "the unused connection is released once");
        });
    }

    public static String failedBeforeConnection() {
        return run(true, false, connection -> {
            await(connection.opening, "worker opening a connection");
            connection.refuses.set(true);
            connection.mayOpen.countDown();
            finished(connection, false);
            require(connection.reads.get() == 0, "a failed connection starts no I/O");
            require(connection.closes.get() == 0, "no connection was handed to the request");
        });
    }

    public static String cancelledDuringResponse() {
        return run(false, true, connection -> {
            await(connection.reading, "response I/O");
            StateUIRequests.cancel(latestTicket);
            StateUIRequests.cancel(latestTicket);
            finished(connection);
            require(connection.closes.get() == 1, "repeated cancellation releases the connection once");
        });
    }

    public static String cancelledAfterWorker() {
        for (int index = 0; index < 32; index++) {
            String failure = run(false, false, connection -> {
                finished(connection);
                StateUIRequests.cancel(latestTicket);
                StateUIRequests.cancel(latestTicket);
                require(StateUIRequests.waitingForTesting() == 0, "a late cancellation creates no native record");
                require(connection.closes.get() == 1, "a late cancellation releases no connection again");
            });
            if (!failure.isEmpty()) return "iteration " + index + ": " + failure;
        }
        return "";
    }

    public static String cancelLatest() {
        StateUIRequests.cancel(latestTicket);
        return StateUIRequests.waitingForTesting() == 0 ? "" : "cancellation after the answer left a record";
    }

    private interface Check { void run(Connection connection) throws Exception; }

    private static String run(boolean holdOpening, boolean holdResponse, Check check) {
        if (!installation.isEmpty()) return installation;
        Connection connection = null;
        try {
            require(StateUIRequests.waitingForTesting() == 0, "no request from another test stands");
            latestTicket = nextTicket--;
            URL address = new URL("stateui-request-test://connection/" + -latestTicket);
            connection = new Connection(address, holdOpening, holdResponse);
            connections.put(address.toExternalForm(), connection);
            StateUIRequests.send(latestTicket, address.toExternalForm(), "GET", new String[0], new byte[0]);
            check.run(connection);
            return "";
        } catch (Exception | AssertionError failure) {
            return failure.toString();
        } finally {
            if (connection != null) {
                connection.mayOpen.countDown();
                connection.mayRespond.countDown();
                StateUIRequests.cancel(latestTicket);
                connections.remove(connection.getURL().toExternalForm());
            }
        }
    }

    private static void finished(Connection connection) throws IOException {
        finished(connection, true);
    }

    private static void finished(Connection connection, boolean hasConnection) throws IOException {
        long until = System.nanoTime() + TimeUnit.SECONDS.toNanos(3);
        while ((StateUIRequests.waitingForTesting() != 0 || (hasConnection && connection.closes.get() == 0))
                && System.nanoTime() < until) {
            LockSupport.parkNanos(TimeUnit.MILLISECONDS.toNanos(1));
        }
        require(StateUIRequests.waitingForTesting() == 0, "a terminal request releases its native record");
        if (hasConnection) require(connection.closes.get() != 0, "a terminal request releases its connection");
    }

    private static void await(CountDownLatch gate, String stage) throws IOException {
        try {
            if (!gate.await(3, TimeUnit.SECONDS)) throw new IOException("timed out waiting for " + stage);
        } catch (InterruptedException failure) {
            Thread.currentThread().interrupt();
            throw new IOException("interrupted waiting for " + stage, failure);
        }
    }

    private static void require(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }

    private static final class Connection extends HttpURLConnection {
        final CountDownLatch opening = new CountDownLatch(1);
        final CountDownLatch reading = new CountDownLatch(1);
        final CountDownLatch mayOpen;
        final CountDownLatch mayRespond;
        final AtomicInteger reads = new AtomicInteger();
        final AtomicInteger closes = new AtomicInteger();
        final AtomicBoolean refuses = new AtomicBoolean();
        private final AtomicBoolean disconnected = new AtomicBoolean();

        Connection(URL address, boolean holdOpening, boolean holdResponse) {
            super(address);
            mayOpen = new CountDownLatch(holdOpening ? 1 : 0);
            mayRespond = new CountDownLatch(holdResponse ? 1 : 0);
        }

        @Override public void connect() {}
        @Override public boolean usingProxy() { return false; }

        @Override public void disconnect() {
            disconnected.set(true);
            closes.incrementAndGet();
            mayRespond.countDown();
        }

        @Override public int getResponseCode() throws IOException {
            reads.incrementAndGet();
            reading.countDown();
            await(mayRespond, "release of the response");
            if (disconnected.get()) throw new IOException("the request was stopped");
            return 200;
        }

        @Override public Map<String, List<String>> getHeaderFields() { return Map.of(); }
        @Override public InputStream getInputStream() { return new ByteArrayInputStream(new byte[] {1, 2, 3}); }
    }
}
