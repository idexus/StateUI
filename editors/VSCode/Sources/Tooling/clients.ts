// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The extension's connections to the stateui tool: one per workspace folder, opened when first asked for, opened
// again once it ended, and shut down with the extension.

import { ToolingClient } from "./client";

/** One connection per folder. */
export class ToolingClients {
    private readonly opened = new Map<string, Promise<ToolingClient>>();

    /** `connect` opens a folder's connection - `ToolingClient.start` with the tool found. */
    constructor(private readonly connect: (folder: string) => Promise<ToolingClient>) {}

    /**
     * The connection of `folder`: the open one, else a new one - one for every caller asking at once, its promise kept
     * before anything is awaited, and one again once it ended, whoever asks first opening it.
     */
    for(folder: string): Promise<ToolingClient> {
        const known = this.opened.get(folder);
        if (known === undefined) {
            return this.open(folder);
        }
        return known.then((client) => client.isOpen ? client : this.again(folder, known), () => this.again(folder, known));
    }

    /** A new connection of `folder`, kept as its one; forgotten where it failed to open. */
    private open(folder: string): Promise<ToolingClient> {
        const opening = this.connect(folder);
        this.opened.set(folder, opening);
        opening.catch(() => this.opened.get(folder) === opening && this.opened.delete(folder));
        return opening;
    }

    /** The connection of `folder` after `ended`: the one another caller opened since, else a new one. */
    private again(folder: string, ended: Promise<ToolingClient>): Promise<ToolingClient> {
        const current = this.opened.get(folder);
        return current !== undefined && current !== ended ? current : this.open(folder);
    }

    /** Shuts every connection down. */
    async dispose(): Promise<void> {
        const all = [...this.opened.values()];
        this.opened.clear();
        await Promise.all(all.map(async (each) => (await each.catch(() => undefined))?.dispose()));
    }
}
