// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

// A program the process runner's tests run; its first argument names what it does.

func say(_ line: String, error: Bool = false) {
    (error ? FileHandle.standardError : FileHandle.standardOutput).write(Data((line + "\n").utf8))
}

func json<Value: Encodable>(_ value: Value) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return String(decoding: try! encoder.encode(value), as: UTF8.self)
}

let arguments = Array(CommandLine.arguments.dropFirst())
let rest = Array(arguments.dropFirst())

switch arguments.first {
case "arguments":
    say(json(rest))
case "environment":
    let environment = ProcessInfo.processInfo.environment
    say(json(Dictionary(uniqueKeysWithValues: rest.map { ($0, environment[$0]) })))
case "directory":
    say(FileManager.default.currentDirectoryPath)
case "flood":
    let filler = String(repeating: "x", count: 100)
    for index in 0..<Int(rest[0])! {
        say("out \(index) \(filler)")
        say("err \(index) \(filler)", error: true)
    }
case "line":
    say(String(repeating: "x", count: Int(rest[0])!))
    say("done")
case "exit":
    exit(Int32(rest[0])!)
#if !os(Windows)
case "abort":
    abort()
case "deaf":
    signal(SIGTERM, SIG_IGN)
    say("deaf")
    Thread.sleep(forTimeInterval: 60)
case "streams":
    var status = stat()
    fstat(1, &status)
    try! "\(status.st_dev):\(status.st_ino)".write(toFile: rest[0], atomically: true, encoding: .utf8)
#endif
case "descendant":
    // rest: the file the descendant's process identifier is written to, "holds" when the descendant keeps
    // this program's standard output, "stays" when this program waits for it rather than leaving at once.
    let descendant = Process()
    descendant.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
    descendant.arguments = ["sleep", "60"]
    if rest[1] != "holds" { descendant.standardOutput = FileHandle.nullDevice }
    try! descendant.run()
    try! "\(descendant.processIdentifier)".write(toFile: rest[0], atomically: true, encoding: .utf8)
    if rest[2] == "stays" { descendant.waitUntilExit() }
case "sleep":
    Thread.sleep(forTimeInterval: Double(rest[0])!)
default:
    say("unknown: \(arguments)", error: true)
    exit(64)
}
