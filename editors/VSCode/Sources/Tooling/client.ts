// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A connection to the stateui tool: `stateui serve --stdio` for one workspace, its methods called with the types
// they take and answered with the types they give - the operations of the extension's that run through the tool.

import { spawn } from "child_process";
import * as os from "os";
import { randomUUID } from "crypto";
import { decode, Decoder, DecodingError } from "./decoding";
import { encodeFrame, FrameReader } from "./frames";
import {
    apiVersions, InitializeResult, methods, MutationName, OperationEvent, OperationHandle, OperationSnapshot, OperationState, ParamsOf,
    QueryName, ResultOf, RPCError, terminalStates, ToolingError,
} from "./protocol";

/** The JSON-RPC code of a tool's own error - the domain's, in `tooling` - and of an API the tool does not speak. */
export const toolingErrorCode = -32010;
export const incompatibleAPICode = -32001;

/**
 * A request the tool refused or failed: its JSON-RPC code, the tool's own error where it gave one, and for an
 * operation that did not succeed, the state it ended in.
 */
export class ToolRequestError extends Error {
    constructor(readonly code: number, message: string, readonly tooling?: ToolingError, readonly state?: OperationState) {
        super(message);
    }
}

/** What follows an operation: each of its events, and a signal that cancels it. */
export interface RunOptions {
    readonly onEvent?: (event: OperationEvent) => void;
    readonly signal?: AbortSignal;
}

/** What opens a connection. */
export interface OpeningOptions {
    /** The workspace the connection opens, as a folder. */
    readonly folder: string;
    /** The extension's release. */
    readonly clientVersion: string;
}

/** What starts the tool and opens a connection to it. */
export interface ConnectionOptions extends OpeningOptions {
    /** The tool's program. */
    readonly executable: string;
    /** Where what the tool says on standard error goes. */
    readonly log?: (line: string) => void;
}

/** The bytes between the extension and the tool. */
export interface Channel {
    write(bytes: Buffer): void;
    /** Hands each piece read to `received`, and why the channel ended, once, to `ended`. */
    listen(received: (bytes: Buffer) => void, ended: (error: Error) => void): void;
    /** Ends the channel at once. */
    close(): void;
}

interface Pending {
    resolve: (value: unknown) => void;
    reject: (error: Error) => void;
}

/** One connection to the tool. */
export class ToolingClient {
    private readonly reader = new FrameReader();
    private readonly pending = new Map<string, Pending>();
    private readonly events = new Map<string, OperationEvent[]>();
    private readonly listeners = new Map<string, (event: OperationEvent) => void>();
    private next = 0;
    private ended?: Error;

    private constructor(private readonly channel: Channel, readonly initialized: InitializeResult) {}

    /** Whether the connection still runs. */
    get isOpen(): boolean {
        return this.ended === undefined;
    }

    /** Starts `stateui serve --stdio` and opens the connection. */
    static start(options: ConnectionOptions): Promise<ToolingClient> {
        // The folder reaches the tool as the connection's workspace; it runs from the user's home, as a process's
        // working directory keeps its folder from being removed or renamed on Windows.
        const child = spawn(options.executable, ["serve", "--stdio"], { cwd: os.homedir(), stdio: ["pipe", "pipe", "pipe"] });
        child.stderr.on("data", (chunk: Buffer) => options.log?.(chunk.toString("utf8").trimEnd()));
        return ToolingClient.open({
            write: (bytes) => child.stdin.write(bytes),
            listen: (received, ended) => {
                child.stdout.on("data", received);
                child.on("error", ended);
                child.on("exit", (code) => ended(new Error(`stateui ended (${code ?? "signal"})`)));
            },
            close: () => child.kill(),
        }, options);
    }

    /**
     * Opens the connection over `channel`; refused when the tool speaks no API version the extension does. A connection
     * that does not open closes its channel - the tool's process with it.
     */
    static async open(channel: Channel, options: OpeningOptions): Promise<ToolingClient> {
        const client = new ToolingClient(channel, undefined as unknown as InitializeResult);
        channel.listen((bytes) => client.receive(bytes), (error) => client.end(error));
        try {
            const result = await client.call("initialize", {
                apiVersions, client: { name: "stateui-vscode", version: options.clientVersion },
                workspaceUri: pathToFileUri(options.folder),
            });
            (client as { initialized: InitializeResult }).initialized = decode(InitializeResult, result);
        } catch (error) {
            channel.close();
            throw error;
        }
        client.notify("initialized");
        return client;
    }

    /** Calls a method answered at once. */
    async request<K extends QueryName>(method: K, params: ParamsOf<K>): Promise<ResultOf<K>> {
        return decode(methods[method].result as Decoder<ResultOf<K>>, await this.call(method, params));
    }

    /**
     * Calls a method starting an operation, follows its events, and gives its result once it succeeded; an operation
     * that did not is thrown as a `ToolRequestError` with the state it ended in.
     */
    async run<K extends MutationName>(method: K, params: ParamsOf<K>, options: RunOptions = {}): Promise<ResultOf<K>> {
        const handle = decode(OperationHandle, await this.call(method, { ...(params as object), requestToken: randomUUID() }));
        const cancel = (): void => void this.request("operation/cancel", { operationId: handle.operationId }).catch(() => undefined);
        options.signal?.addEventListener("abort", cancel, { once: true });
        if (options.signal?.aborted) {
            cancel();
        }
        await new Promise<void>((resolve) => {
            this.listeners.set(handle.operationId, (event) => {
                options.onEvent?.(event);
                if (event.event.kind === "state" && terminalStates.has(event.event.state)) {
                    resolve();
                }
            });
            for (const event of this.events.get(handle.operationId) ?? []) {
                this.listeners.get(handle.operationId)?.(event);
            }
            this.events.delete(handle.operationId);
            if (this.ended) {
                resolve();
            }
        });
        this.listeners.delete(handle.operationId);
        options.signal?.removeEventListener("abort", cancel);
        const snapshot: OperationSnapshot = await this.request("operation/get", { operationId: handle.operationId });
        if (snapshot.state !== "succeeded") {
            throw new ToolRequestError(toolingErrorCode, snapshot.failure?.message ?? `the operation ended ${snapshot.state}`,
                snapshot.failure, snapshot.state);
        }
        return decode(methods[method].result as Decoder<ResultOf<K>>, snapshot.result);
    }

    /** Shuts the tool down and ends the connection. */
    async dispose(): Promise<void> {
        if (this.ended) {
            return;
        }
        try {
            await this.call("shutdown", undefined);
            this.notify("exit");
        } catch {
            this.channel.close();
        }
    }

    private call(method: string, params: unknown): Promise<unknown> {
        if (this.ended) {
            return Promise.reject(this.ended);
        }
        const id = `vscode-${++this.next}`;
        const promise = new Promise<unknown>((resolve, reject) => this.pending.set(id, { resolve, reject }));
        this.channel.write(encodeFrame(params === undefined
            ? { jsonrpc: "2.0", id, method } : { jsonrpc: "2.0", id, method, params }));
        return promise;
    }

    private notify(method: string): void {
        this.channel.write(encodeFrame({ jsonrpc: "2.0", method }));
    }

    private receive(chunk: Buffer): void {
        let messages: unknown[];
        try {
            messages = this.reader.take(chunk);
        } catch (error) {
            this.end(error as Error);
            this.channel.close();
            return;
        }
        for (const message of messages as Record<string, unknown>[]) {
            if (message.method === "operation/event") {
                this.event(message.params);
                continue;
            }
            const pending = typeof message.id === "string" ? this.pending.get(message.id) : undefined;
            if (!pending) {
                continue;
            }
            this.pending.delete(message.id as string);
            if (message.error !== undefined) {
                const error = decode(RPCError, message.error);
                pending.reject(new ToolRequestError(error.code, error.message, error.data));
            } else {
                pending.resolve(message.result);
            }
        }
    }

    /** An operation's event, given to its listener - or kept until one listens, as it may come in the answer's read. */
    private event(params: unknown): void {
        let event: OperationEvent;
        try {
            event = decode(OperationEvent, params);
        } catch (error) {
            if (error instanceof DecodingError) {
                return;
            }
            throw error;
        }
        const listener = this.listeners.get(event.operationId);
        if (listener) {
            listener(event);
        } else {
            this.events.set(event.operationId, [...(this.events.get(event.operationId) ?? []), event]);
        }
    }

    private end(error: Error): void {
        if (this.ended) {
            return;
        }
        this.ended = error;
        for (const pending of this.pending.values()) {
            pending.reject(error);
        }
        this.pending.clear();
        for (const listener of this.listeners.values()) {
            listener({ operationId: "", sequence: 0, timestamp: "", event: { kind: "state", state: "interrupted" } });
        }
    }
}

/** `folder` as a file URI, as the tool reads one. */
export function pathToFileUri(folder: string): string {
    return require("url").pathToFileURL(folder).href;
}
