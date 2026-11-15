// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The extension's half of the stateui tool's API, held to the tool: every message the tool's recorded examples hold
// read by the extension's types and written back the same, and a real `stateui serve --stdio` answering through the
// extension's client. Runs in Node alone - npm run test:tooling.

import * as assert from "assert";
import { spawnSync } from "child_process";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { test } from "node:test";
import { Decoder, decode } from "../../Sources/Tooling/decoding";
import { encodeFrame, FrameReader } from "../../Sources/Tooling/frames";
import { pathToFileUri, ToolingClient, ToolRequestError } from "../../Sources/Tooling/client";
import { InitializeParameters, InitializeResult, methods, OperationEvent, OperationHandle } from "../../Sources/Tooling/protocol";

const repository = path.resolve(__dirname, "..", "..", "..", "..", "..");
const examples = path.join(repository, "tools", "StateUI.CLI", "exports", "protocol");

/** `value` as JSON with every object's keys sorted, so two writings of one value compare alike. */
function canonical(value: unknown): string {
    return JSON.stringify(value, (_key, field) => field && typeof field === "object" && !Array.isArray(field)
        ? Object.fromEntries(Object.entries(field).sort(([a], [b]) => a.localeCompare(b))) : field);
}

function roundTrip<T>(decoder: Decoder<T>, value: unknown, where: string): void {
    assert.strictEqual(canonical(decode(decoder, value)), canonical(value), `${where} is not read whole`);
}

test("every recorded example is read by the extension's types and written back the same", () => {
    const names = fs.readdirSync(examples).filter((file) => file.endsWith(".json")).map((file) => file.slice(0, -5));
    const methodNames = Object.keys(methods);
    for (const method of methodNames) {
        assert.ok(names.includes(method.replace("/", "-")), `${method} has no recorded example`);
    }
    for (const name of names) {
        const example = JSON.parse(fs.readFileSync(path.join(examples, `${name}.json`), "utf8"));
        if (name === "initialize") {
            roundTrip(InitializeParameters, example.request.params, name);
            roundTrip(InitializeResult, example.response.result, name);
        } else if (name === "operation-event") {
            roundTrip(OperationEvent, example.notification.params, name);
        } else if (["initialized", "exit", "shutdown"].includes(name)) {
            continue;
        } else {
            const method = methodNames.find((each) => each.replace("/", "-") === name);
            assert.ok(method, `${name} is no method the extension knows`);
            const declared = methods[method as keyof typeof methods];
            const { requestToken, ...params } = example.request.params ?? {};
            assert.strictEqual(typeof requestToken === "string", declared.kind === "mutation", `${name}'s token`);
            roundTrip(declared.params as Decoder<unknown>, params, `${name}'s request`);
            if (declared.kind === "query") {
                roundTrip(declared.result as Decoder<unknown>, example.response.result, `${name}'s answer`);
            } else {
                roundTrip(OperationHandle, example.response.result, `${name}'s handle`);
                roundTrip(declared.result as Decoder<unknown>, example.result, `${name}'s result`);
            }
        }
    }
});

test("a frame arriving a byte at a time is read once, whole, its length in bytes", () => {
    const reader = new FrameReader();
    const frames = Buffer.concat([encodeFrame({ text: "żółw 🐢" }), encodeFrame([1, 2])]);
    const read: unknown[] = [];
    for (const byte of frames) {
        read.push(...reader.take(Buffer.from([byte])));
    }
    assert.deepStrictEqual(read, [{ text: "żółw 🐢" }, [1, 2]]);
});

/** The tool built from this checkout, where Swift can build it. */
function builtTool(): string | undefined {
    const pkg = path.join(repository, "tools", "StateUI.CLI");
    if (spawnSync("swift", ["build", "--package-path", pkg, "--product", "stateui"], { stdio: "ignore" }).status !== 0) {
        return undefined;
    }
    const bin = spawnSync("swift", ["build", "--package-path", pkg, "--show-bin-path"], { encoding: "utf8" }).stdout.trim();
    const program = path.join(bin, process.platform === "win32" ? "stateui.exe" : "stateui");
    return fs.existsSync(program) ? program : undefined;
}

test("a folder the tool holds a connection for can be removed: the tool runs from outside it", async (context) => {
    const executable = builtTool();
    if (!executable) {
        context.skip("no Swift to build the tool");
        return;
    }
    const folder = fs.mkdtempSync(path.join(os.tmpdir(), "stateui-vscode-"));
    const client = await ToolingClient.start({ executable, folder, clientVersion: "test" });
    try {
        assert.strictEqual(client.initialized.workspace.uri, pathToFileUri(folder));
        fs.rmSync(folder, { recursive: true });
        assert.strictEqual(fs.existsSync(folder), false);
    } finally {
        await client.dispose();
    }
});

test("the extension's client speaks to the tool: queries, an operation's events and result, a refusal", async (context) => {
    const executable = builtTool();
    if (!executable) {
        context.skip("no Swift to build the tool");
        return;
    }
    const client = await ToolingClient.start({ executable, folder: repository, clientVersion: "test" });
    try {
        assert.strictEqual(client.initialized.apiVersion, "1.0");
        assert.strictEqual((await client.request("server/info", {})).server.name, "stateui");
        const project = await client.request("project/describe", {});
        assert.deepStrictEqual(project.applications.map((each) => each.name), ["Gallery", "HelloWorld"]);

        const parent = fs.mkdtempSync(path.join(os.tmpdir(), "stateui-vscode-"));
        const events: string[] = [];
        const creation = await client.run("project/create",
            { name: "Notes", parentUri: pathToFileUri(parent), checkoutUri: pathToFileUri(repository) },
            { onEvent: ({ event }) => events.push(event.kind === "state" ? event.state : event.kind) });
        assert.deepStrictEqual(creation.project.applications.map((each) => each.name), ["Notes"]);
        assert.deepStrictEqual(events, ["running", "succeeded"]);

        const empty = fs.mkdtempSync(path.join(os.tmpdir(), "stateui-vscode-"));
        await assert.rejects(client.request("project/describe", { projectUri: pathToFileUri(empty) }), (error: unknown) =>
            error instanceof ToolRequestError && error.code === -32010 && error.tooling?.code === "PROJECT_NOT_FOUND");
    } finally {
        await client.dispose();
    }
});
