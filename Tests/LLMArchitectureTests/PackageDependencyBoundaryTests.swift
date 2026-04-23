import Foundation
import Testing

private struct PackageManifest {
    let targetDependencies: [String: Set<String>]

    init(contents: String) throws {
        var dependencies: [String: Set<String>] = [:]
        var searchIndex = contents.startIndex

        while let targetRange = contents.range(of: ".target(", range: searchIndex..<contents.endIndex) {
            let block = try Self.block(in: contents, from: targetRange.lowerBound)
            if let name = Self.firstQuotedValue(after: "name:", in: block) {
                dependencies[name] = Self.dependencies(in: block)
            }
            searchIndex = block.endIndex
        }

        targetDependencies = dependencies
    }

    private static func block(in contents: String, from start: String.Index) throws -> Substring {
        guard let open = contents[start...].firstIndex(of: "(") else {
            throw ManifestError.unbalancedTargetBlock
        }

        var depth = 0
        var index = open
        while index < contents.endIndex {
            let character = contents[index]
            if character == "(" {
                depth += 1
            } else if character == ")" {
                depth -= 1
                if depth == 0 {
                    return contents[start...index]
                }
            }
            index = contents.index(after: index)
        }

        throw ManifestError.unbalancedTargetBlock
    }

    private static func dependencies(in block: Substring) -> Set<String> {
        guard
            let labelRange = block.range(of: "dependencies:"),
            let openBracket = block[labelRange.upperBound...].firstIndex(of: "[")
        else {
            return []
        }

        var depth = 0
        var index = openBracket
        while index < block.endIndex {
            let character = block[index]
            if character == "[" {
                depth += 1
            } else if character == "]" {
                depth -= 1
                if depth == 0 {
                    return quotedValues(in: block[openBracket...index])
                }
            }
            index = block.index(after: index)
        }

        return []
    }

    private static func firstQuotedValue(after label: String, in block: Substring) -> String? {
        guard
            let labelRange = block.range(of: label),
            let firstQuote = block[labelRange.upperBound...].firstIndex(of: "\""),
            let secondQuote = block[block.index(after: firstQuote)...].firstIndex(of: "\"")
        else {
            return nil
        }

        return String(block[block.index(after: firstQuote)..<secondQuote])
    }

    private static func quotedValues(in text: Substring) -> Set<String> {
        var values = Set<String>()
        var index = text.startIndex

        while let firstQuote = text[index...].firstIndex(of: "\"") {
            guard let secondQuote = text[text.index(after: firstQuote)...].firstIndex(of: "\"") else {
                break
            }
            values.insert(String(text[text.index(after: firstQuote)..<secondQuote]))
            index = text.index(after: secondQuote)
        }

        return values
    }

    enum ManifestError: Error {
        case packageManifestNotFound
        case unbalancedTargetBlock
    }
}

@Test func packageTargetDependenciesRespectArchitectureBoundaries() throws {
    let manifest = try PackageManifest(contents: packageManifestContents())
    let dependencies = manifest.targetDependencies

    #expect(dependencies["LLMCore"] == [])
    #expect(dependencies["LLMProtocols"] == ["LLMCore"])
    #expect(dependencies["LLMNetworking"] == ["LLMCore"])

    expectNoForbiddenDependencies(
        dependencies["LLMOrchestrator", default: []],
        forbiddenPrefixes: ["LLMBackend", "LLMUI"],
        target: "LLMOrchestrator"
    )

    for target in ["LLMBackendFoundationModels", "LLMBackendCoreML", "LLMBackendMLX", "LLMBackendRemote"] {
        let targetDependencies = dependencies[target, default: []]
        expectNoForbiddenDependencies(targetDependencies, forbiddenPrefixes: ["LLMUI"], target: target)
        expectNoForbiddenDependencies(
            targetDependencies.filter { $0 != target },
            forbiddenPrefixes: ["LLMBackend"],
            target: target
        )
    }

    for target in ["LLMUIChat", "LLMUIDownloads"] {
        expectNoForbiddenDependencies(
            dependencies[target, default: []],
            forbiddenPrefixes: ["LLMBackend", "LLMNetworking", "LLMStorage"],
            target: target
        )
    }

    expectNoForbiddenDependencies(
        dependencies["LLMModelLifecycle", default: []],
        forbiddenPrefixes: ["LLMBackend", "LLMOrchestrator", "LLMUI"],
        target: "LLMModelLifecycle"
    )
}

@Test func sourceImportsRespectArchitectureBoundaries() throws {
    let importsByTarget = try sourceImportsByTarget()
    let allowedLLMImports: [String: Set<String>] = [
        "LLMCore": [],
        "LLMProtocols": ["LLMCore"],
        "LLMSessions": ["LLMCore", "LLMProtocols"],
        "LLMPrompting": ["LLMCore", "LLMProtocols"],
        "LLMTools": ["LLMCore", "LLMProtocols"],
        "LLMSafety": ["LLMCore", "LLMProtocols"],
        "LLMObservability": ["LLMCore", "LLMProtocols"],
        "LLMStorage": ["LLMCore", "LLMProtocols"],
        "LLMDeviceProfiling": ["LLMCore"],
        "LLMNetworking": ["LLMCore"],
        "LLMModelLifecycle": ["LLMCore", "LLMProtocols", "LLMStorage", "LLMObservability"],
        "LLMOrchestrator": [
            "LLMCore",
            "LLMProtocols",
            "LLMSessions",
            "LLMPrompting",
            "LLMTools",
            "LLMSafety",
            "LLMObservability",
            "LLMModelLifecycle",
            "LLMDeviceProfiling"
        ],
        "LLMBackendFoundationModels": ["LLMCore", "LLMProtocols", "LLMObservability"],
        "LLMBackendCoreML": ["LLMCore", "LLMProtocols", "LLMModelLifecycle", "LLMObservability"],
        "LLMBackendMLX": ["LLMCore", "LLMProtocols", "LLMModelLifecycle", "LLMObservability"],
        "LLMBackendRemote": ["LLMCore", "LLMProtocols", "LLMNetworking", "LLMObservability"],
        "LLMUIChat": ["LLMCore", "LLMProtocols", "LLMOrchestrator", "LLMSessions", "LLMTools", "LLMObservability"],
        "LLMUIDownloads": ["LLMCore", "LLMProtocols", "LLMModelLifecycle", "LLMObservability"],
        "LLMExampleUI": [
            "LLMBackendFoundationModels",
            "LLMBackendMLX",
            "LLMCore",
            "LLMModelLifecycle",
            "LLMOrchestrator",
            "LLMProtocols",
            "LLMUIChat",
            "LLMUIDownloads"
        ]
    ]

    for (target, imports) in importsByTarget {
        let llmImports = imports.filter { $0.hasPrefix("LLM") }
        let unexpectedLLMImports = llmImports.subtracting(allowedLLMImports[target, default: []])
        #expect(
            unexpectedLLMImports.isEmpty,
            "\(target) imports disallowed LLM modules: \(unexpectedLLMImports.sorted())"
        )
    }

    let backendFrameworks: Set<String> = ["CoreML", "FoundationModels", "MLX", "MLXLLM"]
    let coreAndCoordinationTargets: Set<String> = [
        "LLMCore",
        "LLMProtocols",
        "LLMSessions",
        "LLMPrompting",
        "LLMTools",
        "LLMSafety",
        "LLMObservability",
        "LLMStorage",
        "LLMDeviceProfiling",
        "LLMModelLifecycle",
        "LLMOrchestrator"
    ]

    for target in coreAndCoordinationTargets {
        let leakedBackendFrameworks = importsByTarget[target, default: []].intersection(backendFrameworks)
        #expect(
            leakedBackendFrameworks.isEmpty,
            "\(target) imports backend frameworks: \(leakedBackendFrameworks.sorted())"
        )
    }

    let swiftUITargets: Set<String> = [
        "LLMUIChat",
        "LLMUIDownloads",
        "LLMExampleUI"
    ]
    for target in importsByTarget.keys where !swiftUITargets.contains(target) {
        #expect(
            !importsByTarget[target, default: []].contains("SwiftUI"),
            "\(target) imports SwiftUI outside the UI layer"
        )
    }
}

@Test func sourceTargetsContainRequiredModuleDocs() throws {
    let requiredDocs: Set<String> = [
        "Overview.md",
        "Responsibilities.md",
        "PublicAPI.md",
        "DependencyRules.md",
        "TODO.md"
    ]
    let sourcesURL = try packageRootURL().appendingPathComponent("Sources")
    let fileManager = FileManager.default
    let targetURLs = try fileManager.contentsOfDirectory(
        at: sourcesURL,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
    )

    for targetURL in targetURLs {
        let resourceValues = try targetURL.resourceValues(forKeys: [.isDirectoryKey])
        guard resourceValues.isDirectory == true else {
            continue
        }

        let docsURL = targetURL.appendingPathComponent("Docs")
        let docNames = Set(
            (try? fileManager.contentsOfDirectory(atPath: docsURL.path)) ?? []
        )
        let missingDocs = requiredDocs.subtracting(docNames)

        #expect(
            missingDocs.isEmpty,
            "\(targetURL.lastPathComponent) is missing required docs: \(missingDocs.sorted())"
        )
    }
}

private func expectNoForbiddenDependencies(
    _ dependencies: Set<String>,
    forbiddenPrefixes: [String],
    target: String,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let forbidden = dependencies.filter { dependency in
        forbiddenPrefixes.contains { dependency.hasPrefix($0) }
    }

    #expect(
        forbidden.isEmpty,
        "\(target) has forbidden dependencies: \(forbidden.sorted())",
        sourceLocation: sourceLocation
    )
}

private func packageManifestContents() throws -> String {
    try String(contentsOf: packageRootURL().appendingPathComponent("Package.swift"), encoding: .utf8)
}

private func sourceImportsByTarget() throws -> [String: Set<String>] {
    let sourcesURL = try packageRootURL().appendingPathComponent("Sources")
    let fileManager = FileManager.default
    guard let enumerator = fileManager.enumerator(
        at: sourcesURL,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        return [:]
    }

    var importsByTarget: [String: Set<String>] = [:]
    for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
        let relativePath = fileURL.path.replacingOccurrences(of: sourcesURL.path + "/", with: "")
        guard let target = relativePath.split(separator: "/").first.map(String.init) else {
            continue
        }

        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        importsByTarget[target, default: []].formUnion(imports(in: contents))
    }

    return importsByTarget
}

private func imports(in contents: String) -> Set<String> {
    Set(contents.split(separator: "\n").compactMap { line in
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("import ") else {
            return nil
        }

        return trimmed
            .dropFirst("import ".count)
            .split(separator: " ")
            .last
            .map(String.init)
    })
}

private func packageRootURL() throws -> URL {
    let fileManager = FileManager.default
    var directory = URL(fileURLWithPath: fileManager.currentDirectoryPath)

    while true {
        let manifestURL = directory.appendingPathComponent("Package.swift")
        if fileManager.fileExists(atPath: manifestURL.path) {
            return directory
        }

        let parent = directory.deletingLastPathComponent()
        if parent.path == directory.path {
            throw PackageManifest.ManifestError.packageManifestNotFound
        }
        directory = parent
    }
}
