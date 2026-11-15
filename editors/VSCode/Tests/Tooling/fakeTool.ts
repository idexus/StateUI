// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A stateui tool in the test's own process, answering the client through a channel as the tool does: an operation
// told before its answer, one held until it is cancelled, an API refused, bytes that are no frame.

import * as fs from "fs";
import * as path from "path";
import { Channel } from "../../Sources/Tooling/client";
import { encodeFrame, FrameReader } from "../../Sources/Tooling/frames";
import { OperationState } from "../../Sources/Tooling/protocol";

interface Message { id?: string; method?: string; params?: { operationId?: string; requestToken?: string } }

const examples = path.resolve(__dirname, "..", "..", "..", "..", "..", "tools", "StateUI.CLI", "exports", "protocol");
const example = (name: string) => JSON.parse(fs.readFileSync(path.join(examples, `${name}.json`), "utf8"));

/** What the fake tool does: refuse every API, hold each operation until it is cancelled, answer a method with no frame. */
export interface FakeBehavior {
    readonly refusesAPI?: boolean;
    readonly holdsOperations?: boolean;
    readonly breaksOn?: string;
}

export class FakeTool implements Channel {
    private readonly reader = new FrameReader();
    private received?: (bytes: Buffer) => void;
    private ended?: (error: Error) => void;
    private readonly operations = new Map<string, { token: string; state: OperationState; sequence: number }>();
    /** Each method the client called, notifications included, in order. */
    readonly calls: string[] = [];
    closed = false;

    constructor(private readonly behavior: FakeBehavior = {}) {}

    write(bytes: Buffer): void {
        for (const message of this.reader.take(bytes) as Message[]) {
            this.calls.push(message.method ?? "");
            setImmediate(() => this.answer(message));
        }
    }

    listen(received: (bytes: Buffer) => void, ended: (error: Error) => void): void {
        this.received = received;
        this.ended = ended;
    }

    close(): void {
        this.closed = true;
        this.end(new Error("closed"));
    }

    /** Ends as a tool that exited. */
    end(error: Error): void {
        const ended = this.ended;
        this.ended = undefined;
        ended?.(error);
    }

    private send(message: unknown): void {
        this.received?.(encodeFrame(message));
    }

    private tell(operationId: string, state: OperationState): void {
        const operation = this.operations.get(operationId)!;
        operation.state = state;
        operation.sequence += 1;
        this.send({ jsonrpc: "2.0", method: "operation/event", params: {
            operationId, sequence: operation.sequence, timestamp: "2026-11-13T12:00:00Z", event: { kind: "state", state },
        } });
    }

    private answer(message: Message): void {
        if (message.id === undefined) {
            return;
        }
        const reply = (result: unknown) => this.send({ jsonrpc: "2.0", id: message.id, result });
        const refuse = (code: number, text: string) => this.send({ jsonrpc: "2.0", id: message.id, error: { code, message: text } });
        if (message.method === this.behavior.breaksOn) {
            this.received?.(Buffer.from("Content-Type: text/plain\r\n\r\n", "ascii"));
            return;
        }
        switch (message.method) {
        case "initialize":
            return this.behavior.refusesAPI
                ? refuse(-32001, "The tool speaks API 2.0-2.0 only.") : reply(example("initialize").response.result);
        case "shutdown":
            return reply(null);
        case "project/create": {
            const operationId = `operation-${this.operations.size + 1}`;
            this.operations.set(operationId, { token: message.params?.requestToken ?? "", state: "queued", sequence: 0 });
            this.tell(operationId, "running");
            reply({ operationId, state: "running" });
            if (!this.behavior.holdsOperations) {
                this.tell(operationId, "succeeded");
            }
            return;
        }
        case "operation/cancel": {
            const operationId = message.params?.operationId ?? "";
            this.tell(operationId, "cancelled");
            return reply({ accepted: true, state: "cancelled" });
        }
        case "operation/get": {
            const id = message.params?.operationId ?? "";
            const operation = this.operations.get(id)!;
            const result = operation.state === "succeeded" ? { result: example("project-create").result } : {};
            return reply({ id, kind: "project/create", requestToken: operation.token, state: operation.state,
                createdAt: "2026-11-13T12:00:00Z", lastSequence: operation.sequence, ...result });
        }
        default:
            return refuse(-32601, `No method ${message.method}.`);
        }
    }
}
