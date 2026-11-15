// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The extension's client against a tool in the test's own process: an operation followed and cancelled, an API and
// bytes refused, a connection opened again once it ended, and the tool found where the extension looks.

import * as assert from "assert";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { test } from "node:test";
import { incompatibleAPICode, ToolingClient, ToolRequestError } from "../../Sources/Tooling/client";
import { ToolingClients } from "../../Sources/Tooling/clients";
import { FramingError } from "../../Sources/Tooling/frames";
import { locateTool, ToolNotFound } from "../../Sources/Tooling/locate";
import { FakeBehavior, FakeTool } from "./fakeTool";

const opened = async (behavior: FakeBehavior = {}) => {
    const tool = new FakeTool(behavior);
    return { tool, client: await ToolingClient.open(tool, { folder: os.tmpdir(), clientVersion: "test" }) };
};

const creation = { name: "Notes", parentUri: "file:///tmp/apps" };

test("an operation's event sent before its answer reaches its follower, and its result comes once it succeeded", async () => {
    const { tool, client } = await opened();
    const states: string[] = [];
    const made = await client.run("project/create", creation,
        { onEvent: ({ event }) => event.kind === "state" && states.push(event.state) });
    assert.deepStrictEqual(states, ["running", "succeeded"]);
    assert.deepStrictEqual(made.project.applications.map((each) => each.name), ["Notes"]);
    await client.dispose();
    assert.deepStrictEqual(tool.calls, ["initialize", "initialized", "project/create", "operation/get", "shutdown", "exit"]);
});

test("an operation whose signal aborts is cancelled, and ends as a refusal saying so", async () => {
    const { tool, client } = await opened({ holdsOperations: true });
    const cancelled = new AbortController();
    const running = client.run("project/create", creation, { signal: cancelled.signal, onEvent: () => cancelled.abort() });
    await assert.rejects(running, (error: unknown) => error instanceof ToolRequestError && error.state === "cancelled");
    assert.ok(tool.calls.includes("operation/cancel"));
    await client.dispose();
});

test("a tool of another API is refused at opening, by its code", async () => {
    await assert.rejects(opened({ refusesAPI: true }),
        (error: unknown) => error instanceof ToolRequestError && error.code === incompatibleAPICode);
});

test("bytes that are no frame end the connection: what waits is refused, and the tool is closed", async () => {
    const { tool, client } = await opened({ breaksOn: "server/info" });
    await assert.rejects(client.request("server/info", {}), FramingError);
    assert.strictEqual(client.isOpen, false);
    assert.strictEqual(tool.closed, true);
    await assert.rejects(client.request("server/info", {}), FramingError);
});

test("an operation followed when the tool ends is refused with why it ended", async () => {
    const { tool, client } = await opened({ holdsOperations: true });
    const running = client.run("project/create", creation, { onEvent: () => tool.end(new Error("stateui ended (1)")) });
    await assert.rejects(running, /stateui ended \(1\)/);
});

test("a folder keeps one connection while it is open, and gets another once it ended", async () => {
    const tools: FakeTool[] = [];
    const clients = new ToolingClients((folder) => {
        const tool = new FakeTool();
        tools.push(tool);
        return ToolingClient.open(tool, { folder, clientVersion: "test" });
    });
    const first = await clients.for("/a");
    assert.strictEqual(await clients.for("/a"), first);
    assert.notStrictEqual(await clients.for("/b"), first);
    tools[0].end(new Error("stateui ended (6)"));
    const again = await clients.for("/a");
    assert.notStrictEqual(again, first);
    assert.ok(again.isOpen);
    await clients.dispose();
    assert.ok(tools.slice(1).every((each) => each.calls.includes("shutdown")));
});

test("the tool is the program stateui.cliPath names, else the search path's stateui", (context) => {
    const folder = fs.mkdtempSync(path.join(os.tmpdir(), "stateui-locate-"));
    const program = path.join(folder, process.platform === "win32" ? "stateui.exe" : "stateui");
    fs.writeFileSync(program, "");
    const searchPath = process.env.PATH;
    context.after(() => {
        process.env.PATH = searchPath;
    });
    assert.strictEqual(locateTool(program), program);
    assert.throws(() => locateTool(path.join(folder, "missing")), (error: unknown) =>
        error instanceof ToolNotFound && error.message.includes("stateui.cliPath names"));
    assert.throws(() => locateTool(folder), ToolNotFound);
    process.env.PATH = folder;
    assert.strictEqual(locateTool(undefined), program);
    assert.strictEqual(locateTool("  "), program);
    process.env.PATH = os.tmpdir();
    assert.throws(() => locateTool(undefined), (error: unknown) =>
        error instanceof ToolNotFound && error.message.includes("search path"));
});
