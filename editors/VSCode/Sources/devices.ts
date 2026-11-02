// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The Android devices a head runs on: what .scripts/Android/devices.sh lists,
// the one chosen for the workspace, and an emulator started when one is picked.

import { execFile } from "child_process";
import * as path from "path";
import * as vscode from "vscode";

/** A place an Android head can run: a device attached and ready, or an emulator not running. */
export type AndroidDevice = AttachedDevice | { readonly kind: "avd"; readonly name: string };

/** A device attached and ready, named by its model - a running emulator by its AVD. */
export interface AttachedDevice {
    readonly kind: "device";
    readonly serial: string;
    readonly name: string;
}

/** The device chosen for a workspace. */
export type ChosenDevice = Omit<AttachedDevice, "kind">;

const deviceKey = "stateui.androidDevice";

/** One of the scripts in `root`/.scripts/Android, which build and run the Android host. */
export function androidScript(root: string, script: "devices.sh" | "run-app.sh" | "test-android.sh"): string {
    return path.join(root, ".scripts", "Android", script);
}

/** What `devices.sh list` printed: one place a line, tab-separated. */
export function parseDevices(output: string): AndroidDevice[] {
    return output.split(/\r?\n/).flatMap((line): AndroidDevice[] => {
        const [kind, first, second] = line.trim().split("\t");
        if (kind === "device" && first) {
            return [{ kind, serial: first, name: second || first }];
        }
        return kind === "avd" && first ? [{ kind, name: first }] : [];
    });
}

/** The device chosen for the workspace, where one is. */
export function chosenDevice(state: vscode.Memento): ChosenDevice | undefined {
    return state.get<ChosenDevice>(deviceKey);
}

/**
 * The serial of the device a launch or a suite runs on: the one chosen, while
 * it is attached, else asked for - or nothing, where none is picked.
 */
export async function deviceToRunOn(root: string, state: vscode.Memento): Promise<string | undefined> {
    const listed = await listDevices(root);
    const chosen = chosenDevice(state);

    if (chosen && listed?.some((each) => each.kind === "device" && each.serial === chosen.serial)) {
        return chosen.serial;
    }
    return listed ? askForDevice(root, state, listed) : undefined;
}

/**
 * Asks for a device among those `devices.sh list` lists - an emulator picked
 * is started first - remembers it, and answers its serial.
 */
export async function askForDevice(root: string, state: vscode.Memento, listed?: AndroidDevice[]): Promise<string | undefined> {
    listed ??= await listDevices(root);
    if (!listed) {
        return undefined;
    }
    if (listed.length === 0) {
        void vscode.window.showErrorMessage(
            "StateUI: no Android device is attached and no emulator is set up - attach a device with USB debugging on, or make an emulator in Android Studio's Device Manager.");
        return undefined;
    }

    const current = chosenDevice(state)?.serial;
    const attached = listed.filter((each): each is AttachedDevice => each.kind === "device");
    const emulators = listed.filter((each) => each.kind === "avd");
    type Item = vscode.QuickPickItem & { device?: AndroidDevice };
    const items: Item[] = [
        ...attached.map((device): Item => ({
            label: `$(device-mobile) ${device.name}`, description: device.serial === current ? `${device.serial} · current` : device.serial, device,
        })),
        ...(emulators.length > 0 ? [{ label: "Emulators not running", kind: vscode.QuickPickItemKind.Separator }] : []),
        ...emulators.map((device): Item => ({ label: `$(vm) ${device.name}`, description: "started when picked", device })),
    ];

    const device = (await vscode.window.showQuickPick(items,
        { placeHolder: "Which Android device do StateUI: Debug, StateUI: Release and StateUI: Run Tests run on?", ignoreFocusOut: true }))?.device;
    if (!device) {
        return undefined;
    }

    const serial = device.kind === "device" ? device.serial : await boot(root, device.name);
    if (serial) {
        await state.update(deviceKey, { serial, name: device.name } satisfies ChosenDevice);
    }
    return serial;
}

/** What `devices.sh list` lists, or nothing, said, where it failed. */
async function listDevices(root: string): Promise<AndroidDevice[] | undefined> {
    const { failed, stdout, output } = await devicesScript(root, ["list"]);
    if (failed) {
        void vscode.window.showErrorMessage(`StateUI: the Android devices could not be listed - ${output.trim()}`);
        return undefined;
    }
    return parseDevices(stdout);
}

/** Starts the emulator `avd` and answers its serial once it has booted, or nothing, said, where it did not. */
async function boot(root: string, avd: string): Promise<string | undefined> {
    const { failed, stdout, output } = await vscode.window.withProgress(
        { location: vscode.ProgressLocation.Notification, title: `StateUI: starting ${avd}` },
        () => devicesScript(root, ["boot", avd]));

    const serial = stdout.trim().split(/\r?\n/).pop()?.trim();
    if (failed || !serial) {
        void vscode.window.showErrorMessage(`StateUI: ${avd} did not start - ${output.trim() || "devices.sh said nothing"}`);
        return undefined;
    }
    return serial;
}

function devicesScript(root: string, args: string[]): Promise<{ failed: boolean; stdout: string; output: string }> {
    return new Promise((resolve) => execFile("bash", [androidScript(root, "devices.sh"), ...args], { cwd: root },
        (error, stdout, stderr) => resolve({ failed: error !== null, stdout, output: `${stdout}${stderr}` })));
}
