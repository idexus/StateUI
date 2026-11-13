// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Reading what the stateui tool sends: each message checked against the type it is said to be, so a message the
// extension does not understand is named where it differs instead of read as something it is not.

/** Reads a JSON value as `T`, or throws a `DecodingError` naming where it is not one. */
export type Decoder<T> = (value: unknown, path: string) => T;

/** A JSON value that is not what its type says, by where it stands: `/result/applications/0/name`. */
export class DecodingError extends Error {
    constructor(readonly path: string, reason: string) {
        super(`${path || "/"}: ${reason}`);
    }
}

function expect(condition: boolean, path: string, reason: string): void {
    if (!condition) {
        throw new DecodingError(path, reason);
    }
}

export const string: Decoder<string> = (value, path) => {
    expect(typeof value === "string", path, "not a string");
    return value as string;
};

export const number: Decoder<number> = (value, path) => {
    expect(typeof value === "number" && Number.isFinite(value), path, "not a number");
    return value as number;
};

export const boolean: Decoder<boolean> = (value, path) => {
    expect(typeof value === "boolean", path, "not a boolean");
    return value as boolean;
};

/** Any JSON value, as it came. */
export const json: Decoder<unknown> = (value) => value;

/** One of `values`. */
export function oneOf<T extends string>(...values: T[]): Decoder<T> {
    return (value, path) => {
        expect(typeof value === "string" && (values as string[]).includes(value), path, `not one of ${values.join(", ")}`);
        return value as T;
    };
}

export function array<T>(item: Decoder<T>): Decoder<T[]> {
    return (value, path) => {
        expect(Array.isArray(value), path, "not an array");
        return (value as unknown[]).map((each, index) => item(each, `${path}/${index}`));
    };
}

/** A field left out; `null` is no value of it - the tool leaves an absent field out. */
export function optional<T>(decoder: Decoder<T>): Decoder<T | undefined> {
    return (value, path) => value === undefined ? undefined : decoder(value, path);
}

/** An object of `fields`; a field the extension does not know is passed over, as a newer tool may add one. */
export function object<T>(fields: { [K in keyof T]-?: Decoder<T[K]> }): Decoder<T> {
    return (value, path) => {
        expect(typeof value === "object" && value !== null && !Array.isArray(value), path, "not an object");
        const source = value as Record<string, unknown>;
        const read: Record<string, unknown> = {};
        for (const key of Object.keys(fields) as (keyof T & string)[]) {
            const field = fields[key](source[key], `${path}/${key}`);
            if (field !== undefined) {
                read[key] = field;
            }
        }
        return read as T;
    };
}

/** `value` read as `decoder`'s type. */
export function decode<T>(decoder: Decoder<T>, value: unknown): T {
    return decoder(value, "");
}
