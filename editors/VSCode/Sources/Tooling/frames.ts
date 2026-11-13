// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The stateui tool's frames: `Content-Length`, a blank line, a JSON body - the length in bytes, the bytes in
// whatever pieces a pipe gives them.

/** A message as a frame. */
export function encodeFrame(message: unknown): Buffer {
    const body = Buffer.from(JSON.stringify(message), "utf8");
    return Buffer.concat([Buffer.from(`Content-Length: ${body.length}\r\n\r\n`, "ascii"), body]);
}

/** Bytes that cannot be a frame: the connection ends. */
export class FramingError extends Error {}

/** Frames read out of the bytes a pipe delivers. */
export class FrameReader {
    private buffer = Buffer.alloc(0);

    /** The bodies, parsed, of the frames `chunk` completes. */
    take(chunk: Buffer): unknown[] {
        this.buffer = Buffer.concat([this.buffer, chunk]);
        const messages: unknown[] = [];
        for (;;) {
            const end = this.buffer.indexOf("\r\n\r\n");
            if (end < 0) {
                if (this.buffer.length > 8 * 1024) {
                    throw new FramingError("a header past 8 KiB");
                }
                return messages;
            }
            const header = this.buffer.subarray(0, end).toString("ascii");
            const length = header.split("\r\n")
                .map((line) => line.match(/^content-length:\s*(\d+)\s*$/i)?.[1])
                .find((value) => value !== undefined);
            if (length === undefined) {
                throw new FramingError(`a header with no length: ${header}`);
            }
            const start = end + 4;
            const size = Number(length);
            if (this.buffer.length < start + size) {
                return messages;
            }
            messages.push(JSON.parse(this.buffer.subarray(start, start + size).toString("utf8")));
            this.buffer = this.buffer.subarray(start + size);
        }
    }
}
