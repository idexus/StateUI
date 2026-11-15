// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Where the stateui tool stands: the program `stateui.cliPath` names, else `stateui` on the search path.

import * as fs from "fs";
import * as os from "os";
import * as path from "path";

/** Where `name` stands on the search path - with Windows' own extensions for a program - or undefined. */
export function onPath(name: string, platform: NodeJS.Platform = process.platform): string | undefined {
    const extensions = platform === "win32" ? (process.env.PATHEXT ?? ".EXE;.CMD;.BAT").split(";") : [""];
    for (const directory of (process.env.PATH ?? "").split(path.delimiter).filter((each) => each.length > 0)) {
        for (const extension of extensions) {
            const candidate = path.join(directory, name + extension.toLowerCase());
            if (fs.existsSync(candidate) && fs.statSync(candidate).isFile()) {
                return candidate;
            }
        }
    }
    return undefined;
}

/** No tool where the extension looked: what it looked for. */
export class ToolNotFound extends Error {}

/** The tool `configured` names - `~` its user's home - else the search path's `stateui`. */
export function locateTool(configured: string | undefined, platform: NodeJS.Platform = process.platform): string {
    const named = configured?.trim().replace(/^~(?=$|[\\/])/, os.homedir());
    if (named) {
        if (fs.existsSync(named) && fs.statSync(named).isFile()) {
            return named;
        }
        throw new ToolNotFound(`stateui.cliPath names ${named}, which is no program.`);
    }
    const found = onPath("stateui", platform);
    if (!found) {
        throw new ToolNotFound("the stateui tool is not on the search path: install it, or name it with stateui.cliPath.");
    }
    return found;
}
