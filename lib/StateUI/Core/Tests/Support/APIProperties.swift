// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

// The compiler's public accessors and synthesized projections supplement its symbol graph.
// Design: docs/design/architecture.md#the-public-surface
struct APIProperties {
    struct Property {
        let path: String
        let name: String
        let type: String
        let accessors: Set<String>
    }

    private var properties: [String: Property] = [:]
    private var projections: [Property] = []

    init(_ json: [String: Any], module: String) throws {
        guard let root = json["ABIRoot"] as? [String: Any] else {
            throw CocoaError(.propertyListReadCorrupt)
        }
        read(root, parents: [], module: module)
    }

    private mutating func read(_ node: [String: Any], parents: [String], module: String) {
        let name = node["name"] as? String ?? ""
        let kind = node["kind"] as? String ?? ""
        let children = node["children"] as? [[String: Any]] ?? []
        if kind == "Var", node["declKind"] as? String == "Var", node["moduleName"] as? String == module,
           let identifier = node["usr"] as? String, let type = children.first?["printedName"] as? String {
            let accessors = node["accessors"] as? [[String: Any]] ?? []
            let property = Property(
                path: (parents + [name]).joined(separator: "."), name: name,
                type: type.replacingOccurrences(of: module + ".", with: "").replacingOccurrences(of: "Swift.", with: ""),
                accessors: Set(accessors.compactMap { $0["accessorKind"] as? String }))
            properties[identifier] = property
            if name.hasPrefix("$") { projections.append(property) }
        }
        let scope = kind == "TypeDecl" ? parents + [name] : parents
        for child in children { read(child, parents: scope, module: module) }
    }

    func declaration(_ declaration: String, of identifier: String) -> String {
        let original = identifier.components(separatedBy: "::SYNTHESIZED::")[0]
        guard let property = properties[original], !property.accessors.contains("set"),
              let start = declaration.range(of: " {", options: .backwards), declaration.hasSuffix("}") else {
            return declaration
        }
        let accessors = declaration[start.lowerBound...]
            .replacingOccurrences(of: " nonmutating set", with: "")
            .replacingOccurrences(of: " mutating set", with: "")
            .replacingOccurrences(of: " set", with: "")
        return declaration[..<start.lowerBound] + accessors
    }

    func projectedLines(declarations: [String: String], wrappers: Set<String>) throws -> [String] {
        try projections.compactMap { property in
            let wrapped = String(property.path.dropLast(property.name.count)) + property.name.dropFirst()
            // The public graph is the access filter: an SPI or hidden wrapped property publishes no projection.
            guard let declaration = declarations[wrapped] else { return nil }
            guard let variable = declaration.range(of: "var " + property.name.dropFirst()),
                  property.accessors.contains("get") else { throw CocoaError(.propertyListReadCorrupt) }
            var prefix = String(declaration[..<variable.lowerBound])
            for wrapper in wrappers.sorted() {
                prefix = prefix.replacingOccurrences(of: "@\(wrapper) ", with: "")
            }
            let accessors = property.accessors.contains("set") ? "get set" : "get"
            return "swift.property \(property.path): \(prefix)var \(property.name): \(property.type) { \(accessors) }"
        }.sorted()
    }
}
