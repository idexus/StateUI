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

    /** The connection of `folder`: the open one, else a new one. */
    async for(folder: string): Promise<ToolingClient> {
        const open = await this.opened.get(folder)?.catch(() => undefined);
        if (open?.isOpen) {
            return open;
        }
        const opening = this.connect(folder);
        this.opened.set(folder, opening);
        opening.catch(() => this.opened.get(folder) === opening && this.opened.delete(folder));
        return opening;
    }

    /** Shuts every connection down. */
    async dispose(): Promise<void> {
        const all = [...this.opened.values()];
        this.opened.clear();
        await Promise.all(all.map(async (each) => (await each.catch(() => undefined))?.dispose()));
    }
}
