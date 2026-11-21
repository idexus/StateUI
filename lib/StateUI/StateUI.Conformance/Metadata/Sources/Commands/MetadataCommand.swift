// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIConformance
@_spi(Host) import StateUIFoundation

/// `stateui-conformance-metadata --repository <path> --host <host> --format json`: every conformance family, the
/// revision its verdicts on the host stand at as `revisions.txt` says, the verdict files recorded for it with the
/// revision each names, and whether they are fresh, stale, missing or unreadable - read by `HostVerdict`, the one
/// owner of a revision, for the stateui tool.
/// Design: docs/design/tooling/repository.md#a-familys-revision
@main
struct MetadataCommand {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        func value(_ name: String) -> String? {
            arguments.firstIndex(of: name).flatMap { arguments.index(after: $0) < arguments.endIndex ? arguments[$0 + 1] : nil }
        }
        guard let repository = value("--repository"), let host = value("--host"), value("--format") ?? "json" == "json" else {
            writeStandardError("usage: stateui-conformance-metadata --repository <path> --host <host> --format json\n")
            exit(64)
        }
        guard let revisions = text(at: "\(repository)/lib/StateUI/StateUI.Conformance/revisions.txt") else {
            writeStandardError("no lib/StateUI/StateUI.Conformance/revisions.txt in \(repository)\n")
            exit(66)
        }
        let marks = "\(repository)/lib/StateUI/exports/marks/\(host)"
        let families = Families.all.map { family in
            describe(family.name, host: host, marks: marks, revisions: revisions)
        }
        print("{\"host\":\(quoted(host)),\"families\":[\(families.joined(separator: ","))]}")
    }

    /// A family's entry: its revision, its files - `<Family>.txt`, else its parts `<Family>-1.txt`, … - and their
    /// state.
    static func describe(_ name: String, host: String, marks: String, revisions: String) -> String {
        let expected = HostVerdict.revision(of: name, on: host, in: revisions)
        var files: [(name: String, text: String)] = []
        if let whole = text(at: "\(marks)/\(name).txt") {
            files.append(("\(name).txt", whole))
        } else {
            var part = 1
            while let piece = text(at: "\(marks)/\(name)-\(part).txt") {
                files.append(("\(name)-\(part).txt", piece))
                part += 1
            }
        }
        let status = switch HostVerdict.standing(of: files.map(\.text), family: name, on: host, in: revisions) {
        case .fresh: "fresh"
        case .stale: "stale"
        case .missing: "missing"
        case .invalid: "invalid"
        }
        let listed = files.map { "{\"name\":\(quoted($0.name)),\"revision\":\(HostVerdict.revision(of: $0.text).map(quoted) ?? "null")}" }
        return "{\"name\":\(quoted(name)),\"revision\":\(quoted(expected)),\"status\":\(quoted(status)),\"files\":[\(listed.joined(separator: ","))]}"
    }

    /// `string` as a JSON string.
    static func quoted(_ string: String) -> String {
        var escaped = "\""
        for scalar in string.unicodeScalars {
            switch scalar {
            case "\"": escaped += "\\\""
            case "\\": escaped += "\\\\"
            case "\n": escaped += "\\n"
            default: escaped.unicodeScalars.append(scalar)
            }
        }
        return escaped + "\""
    }

    /// The text of the file at `path`, or nil where there is none.
    static func text(at path: String) -> String? {
        guard let file = opened(path) else { return nil }
        defer { fclose(file) }
        var bytes: [UInt8] = []
        var buffer = [UInt8](repeating: 0, count: 1 << 16)
        while true {
            let count = fread(&buffer, 1, buffer.count, file)
            if count <= 0 { break }
            bytes += buffer[0..<count]
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    /// The file at `path` opened to read its bytes, by the call each platform's C library offers for it.
    private static func opened(_ path: String) -> UnsafeMutablePointer<FILE>? {
        #if os(Windows)
        var file: UnsafeMutablePointer<FILE>?
        return fopen_s(&file, path, "rb") == 0 ? file : nil
        #else
        return fopen(path, "rb")
        #endif
    }
}
