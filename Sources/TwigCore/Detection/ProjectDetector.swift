import Foundation

/// A read-only, bounded source of launch suggestions. It never runs a project's tools or scripts.
/// Explicit editor metadata is stronger evidence than a language or build-system convention.
public struct ProjectDetector: Sendable {
    public init() {}

    public func detect(at root: URL) -> ProjectDetection {
        let root = root.standardizedFileURL
        guard root.isFileURL,
              let rootValues = try? root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
              rootValues.isDirectory == true, rootValues.isSymbolicLink != true else {
            return ProjectDetection(candidates: [], scannedFileCount: 0, wasTruncated: false)
        }
        var scan = ProjectScan(root: root)
        scan.run()
        var suggestions = Suggestions(root: root, entries: scan.entries)
        suggestions.collect()
        return ProjectDetection(
            candidates: suggestions.ranked,
            scannedFileCount: scan.fileCount,
            wasTruncated: scan.truncated || suggestions.contentWasTruncated
        )
    }
}

private struct ScanEntry {
    let url: URL
    let relativePath: String
    let isDirectory: Bool
    var name: String { url.lastPathComponent }
    var lowerName: String { name.lowercased() }
    var ext: String { url.pathExtension.lowercased() }
    var parent: URL { url.deletingLastPathComponent() }
}

private struct ProjectScan {
    static let maximumEntries = 6_000
    static let maximumDirectoryDepth = 4
    static let ignoredDirectories: Set<String> = [
        ".git", ".hg", ".svn", "node_modules", "vendor", "pods", "carthage",
        ".build", "build", "builds", "dist", "target", "deriveddata", "out",
        ".gradle", ".next", ".nuxt", ".cache", ".turbo", ".venv", "venv",
        "env", "__pycache__", ".tox", ".mypy_cache", ".pytest_cache", "coverage",
        "bower_components", ".dart_tool", ".pub-cache", ".swiftpm", ".yarn",
        ".pnpm-store", "library", "temp", "obj", "bin", ".terraform"
    ]
    static let packageExtensions: Set<String> = ["xcodeproj", "xcworkspace", "app", "framework", "xcassets", "bundle", "playground"]
    let root: URL
    var entries: [ScanEntry] = []
    var fileCount = 0
    var truncated = false

    mutating func run() {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey, .isRegularFileKey]
        // Visit each level before descending so a large source folder cannot hide root manifests.
        // Shallow enumerators keep this lazy even if a folder contains thousands of entries.
        var pending = [root]
        var nextDirectory = 0
        var visited = 0
        defer { entries.sort { $0.relativePath < $1.relativePath } }
        while nextDirectory < pending.count {
            let directory = pending[nextDirectory]
            nextDirectory += 1
            guard let enumerator = FileManager.default.enumerator(
                at: directory, includingPropertiesForKeys: Array(keys),
                options: [.skipsSubdirectoryDescendants], errorHandler: { _, _ in true }
            ) else { continue }
            var children: [URL] = []
            for case let url as URL in enumerator {
                visited += 1
                if visited > Self.maximumEntries {
                    truncated = true
                    return
                }
                guard let values = try? url.resourceValues(forKeys: keys) else { continue }
                guard values.isSymbolicLink != true else { continue }
                let isDirectory = values.isDirectory == true
                // Enumeration may expand /var to /private/var. Normalize both sides before
                // calculating depth or comparing a manifest's folder with editor metadata.
                let url = url.standardizedFileURL
                let relativePath = String(url.path.dropFirst(root.path.count + (root.path == "/" ? 0 : 1)))
                if isDirectory && Self.ignoredDirectories.contains(url.lastPathComponent.lowercased()) { continue }
                guard isDirectory || values.isRegularFile == true else { continue }
                entries.append(ScanEntry(url: url, relativePath: relativePath, isDirectory: isDirectory))
                if isDirectory {
                    if Self.packageExtensions.contains(url.pathExtension.lowercased()) { continue }
                    if relativePath.split(separator: "/").count >= Self.maximumDirectoryDepth {
                        truncated = true
                    } else {
                        children.append(url)
                    }
                } else {
                    fileCount += 1
                }
            }
            pending.append(contentsOf: children.sorted { $0.path < $1.path })
        }
    }
}

private struct Suggestions {
    let root: URL
    let entries: [ScanEntry]
    var candidates: [String: ProjectCandidate] = [:]
    var remainingReadBytes = 1_048_576
    var contentWasTruncated = false
    var cachedContents: [String: String] = [:]

    var ranked: [ProjectCandidate] {
        candidates.values.sorted {
            if $0.confidence != $1.confidence { return $0.confidence > $1.confidence }
            let lhsDepth = $0.target.pathComponents.count
            let rhsDepth = $1.target.pathComponents.count
            if lhsDepth != rhsDepth { return lhsDepth < rhsDepth }
            if $0.ide.rawValue != $1.ide.rawValue { return $0.ide.rawValue < $1.ide.rawValue }
            return $0.target.path < $1.target.path
        }
    }

    mutating func add(_ ide: IDEID, _ target: URL, _ kind: String, _ reason: String, _ score: Int) {
        let candidate = ProjectCandidate(ide: ide, target: target, projectKind: kind, reason: reason, confidence: score)
        if let old = candidates[candidate.id], old.confidence >= score { return }
        candidates[candidate.id] = candidate
    }

    mutating func content(_ entry: ScanEntry) -> String {
        if let cached = cachedContents[entry.url.path] { return cached }
        guard remainingReadBytes > 0 else {
            contentWasTruncated = true
            return ""
        }
        guard let handle = try? FileHandle(forReadingFrom: entry.url) else { return "" }
        defer { try? handle.close() }
        // Read one extra byte to distinguish a complete read from a truncated file.
        let limit = min(65_536, remainingReadBytes)
        guard let bytes = try? handle.read(upToCount: limit + 1) else { return "" }
        let prefix = bytes.prefix(limit)
        remainingReadBytes -= prefix.count
        if bytes.count > limit { contentWasTruncated = true }
        let value = String(decoding: prefix, as: UTF8.self).lowercased()
        cachedContents[entry.url.path] = value
        return value
    }

    mutating func collect() {
        for entry in entries { detectManifest(entry) }
        for entry in entries { detectEditorMetadata(entry) }
        detectSourceLanguages()
        // Generic editors can open any repository. Low scores make this an honest fallback.
        add(.vscode, root, "Folder", "General-purpose editor fallback; no preference is assumed.", 10)
        add(.cursor, root, "Folder", "General-purpose editor fallback.", 9)
        add(.zed, root, "Folder", "General-purpose editor fallback.", 8)
        add(.windsurf, root, "Folder", "General-purpose editor fallback.", 7)
        add(.sublime, root, "Folder", "General-purpose editor fallback.", 6)
        add(.nova, root, "Folder", "General-purpose editor fallback.", 5)
    }

    mutating func detectManifest(_ entry: ScanEntry) {
        let reason = "Found \(entry.relativePath)."
        if entry.isDirectory {
            if entry.ext == "xcworkspace" { add(.xcode, entry.url, "Xcode workspace", reason, 98) }
            if entry.ext == "xcodeproj" { add(.xcode, entry.url, "Xcode project", reason, 95) }
            if entry.ext == "playground" { add(.xcode, entry.url, "Swift playground", reason, 86) }
            return
        }
        let folder = entry.parent
        switch entry.lowerName {
        case "package.swift":
            add(.xcode, entry.url, "Swift package", reason, 86)
            add(.vscode, folder, "Swift package", reason, 61)
        case "cargo.toml":
            add(.rustrover, folder, "Rust", reason, 85)
            add(.vscode, folder, "Rust", reason, 63)
        case "go.mod", "go.work":
            add(.goland, folder, "Go", reason, 85)
            add(.vscode, folder, "Go", reason, 63)
        case "pyproject.toml", "pipfile", "setup.py", "setup.cfg", "requirements.txt", "poetry.lock", "uv.lock":
            add(.pycharm, folder, "Python", reason, 84)
            add(.vscode, folder, "Python", reason, 63)
        case "package.json":
            add(.webstorm, folder, "JavaScript / TypeScript", reason, 80)
            add(.vscode, folder, "JavaScript / TypeScript", reason, 74)
        case "tsconfig.json", "jsconfig.json", "deno.json", "deno.jsonc", "bun.lock", "bun.lockb":
            add(.webstorm, folder, "JavaScript / TypeScript", reason, 78)
            add(.vscode, folder, "JavaScript / TypeScript", reason, 72)
        case "composer.json":
            add(.phpstorm, folder, "PHP", reason, 85)
            add(.vscode, folder, "PHP", reason, 63)
        case "gemfile", "rakefile", ".ruby-version":
            add(.rubymine, folder, "Ruby", reason, 85)
            add(.vscode, folder, "Ruby", reason, 63)
        case "cmakelists.txt", "meson.build", "compile_commands.json", "configure.ac":
            add(.clion, folder, "C / C++", reason, 84)
            add(.vscode, folder, "C / C++", reason, 63)
        case "pom.xml", "build.sbt":
            add(.intellij, folder, "JVM", reason, 84)
            add(.vscode, folder, "JVM", reason, 61)
        case "build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts":
            let text = content(entry)
            if text.contains("com.android.") || text.contains("android.application") || text.contains("android.library") {
                add(.androidStudio, enclosingProject(for: entry, names: ["settings.gradle", "settings.gradle.kts", "build.gradle", "build.gradle.kts"]), "Android", "Android Gradle plugin in \(entry.relativePath).", 90)
            } else {
                add(.intellij, folder, "Gradle / JVM", reason, 81)
            }
            add(.vscode, folder, "Gradle", reason, 60)
        case "pubspec.yaml":
            let text = content(entry)
            let kind = text.contains("flutter:") ? "Flutter" : "Dart"
            add(.androidStudio, folder, kind, reason, 83)
            add(.vscode, folder, kind, reason, 77)
        case "androidmanifest.xml":
            // A source manifest is inside app/src/main; launch the nearest Gradle project.
            add(.androidStudio, enclosingProject(for: entry, names: ["settings.gradle", "settings.gradle.kts", "build.gradle", "build.gradle.kts"]), "Android", reason, 88)
        case "project.godot":
            add(.vscode, folder, "Godot", reason, 74)
        case "mix.exs":
            add(.vscode, folder, "Elixir", reason, 74)
        case "stack.yaml", "cabal.project":
            add(.vscode, folder, "Haskell", reason, 74)
        case "project.toml":
            let text = content(entry)
            if text.contains("[deps]") || text.contains("julia") {
                add(.vscode, folder, "Julia", reason, 74)
            }
        case "project.clj", "deps.edn":
            add(.intellij, folder, "Clojure", reason, 77)
            add(.vscode, folder, "Clojure", reason, 65)
        case "renv.lock":
            add(.rstudio, folder, "R", reason, 84)
        case "description":
            let text = content(entry)
            if text.contains("package:") && text.contains("version:") {
                add(.rstudio, folder, "R package", reason, 84)
            }
        case "projectversion.txt" where entry.parent.lastPathComponent == "ProjectSettings":
            add(.rider, folder.deletingLastPathComponent(), "Unity", reason, 86)
        default: break
        }
        switch entry.ext {
        case "sln", "slnx": add(.rider, entry.url, ".NET solution", reason, 89)
        case "csproj", "fsproj", "vbproj":
            add(.rider, entry.url, ".NET project", reason, 84)
            add(.vscode, folder, ".NET", reason, 63)
        case "uproject": add(.rider, entry.url, "Unreal Engine", reason, 89)
        case "rproj": add(.rstudio, entry.url, "R project", reason, 96)
        case "gemspec": add(.rubymine, folder, "Ruby", reason, 83)
        case "cabal": add(.vscode, folder, "Haskell", reason, 74)
        default: break
        }
    }

    mutating func detectEditorMetadata(_ entry: ScanEntry) {
        let reason = "Explicit editor configuration: \(entry.relativePath)."
        if entry.isDirectory {
            switch entry.lowerName {
            case ".vscode": add(.vscode, entry.parent, "VS Code folder", reason, 97)
            case ".cursor": add(.cursor, entry.parent, "Cursor folder", reason, 97)
            case ".windsurf": add(.windsurf, entry.parent, "Windsurf folder", reason, 97)
            case ".zed": add(.zed, entry.parent, "Zed folder", reason, 97)
            case ".fleet": add(.fleet, entry.parent, "Fleet folder", reason, 97)
            case ".nova": add(.nova, entry.parent, "Nova folder", reason, 97)
            case ".idea": detectJetBrains(in: entry)
            default: break
            }
            return
        }
        switch entry.ext {
        case "code-workspace": add(.vscode, entry.url, "VS Code workspace", reason, 99)
        case "sublime-project": add(.sublime, entry.url, "Sublime project", reason, 99)
        case "ipr": add(.intellij, entry.url, "IntelliJ project", reason, 96)
        default: break
        }
        switch entry.lowerName {
        case ".cursorrules": add(.cursor, entry.parent, "Cursor folder", reason, 97)
        case ".windsurfrules": add(.windsurf, entry.parent, "Windsurf folder", reason, 97)
        default: break
        }
    }

    mutating func detectJetBrains(in directory: ScanEntry) {
        let folder = directory.parent
        let files = entries.filter { !$0.isDirectory && $0.url.path.hasPrefix(directory.url.path + "/") }
        var identified: Set<IDEID> = []
        for file in files {
            let filename = file.lowerName
            if filename == "php.xml" { identified.insert(.phpstorm) }
            if filename == "riderprojectsettingsupdater.xml" { identified.insert(.rider) }
            if filename == "rust.xml" || filename == "rustrover.xml" { identified.insert(.rustrover) }
            if filename == "golibraries.xml" { identified.insert(.goland) }
            if filename == "misc.xml" || file.ext == "iml" {
                let text = content(file)
                if text.contains("python_sdk") || text.contains("python_module") || text.contains("project-jdk-name=\"python") { identified.insert(.pycharm) }
                if text.contains("ruby_sdk") || text.contains("ruby_module") { identified.insert(.rubymine) }
                if text.contains("web_module") || text.contains("javascript_module") { identified.insert(.webstorm) }
                if text.contains("php_module") { identified.insert(.phpstorm) }
                if text.contains("go_module") || text.contains("go sdk") { identified.insert(.goland) }
                if text.contains("type=\"android\"") || text.contains("android.sdk") { identified.insert(.androidStudio) }
                if text.contains("cmakeworkspace") || text.contains("cmake_module") { identified.insert(.clion) }
            }
        }
        if identified.isEmpty {
            // .idea is shared by JetBrains products; pair it with this project's manifests.
            let jetBrains: Set<IDEID> = [.intellij, .androidStudio, .pycharm, .webstorm, .phpstorm, .rubymine, .goland, .clion, .rider, .rustrover]
            let nearby = ranked.filter {
                jetBrains.contains($0.ide) && $0.confidence >= 75 &&
                ($0.target.path == folder.path || $0.target.deletingLastPathComponent().path == folder.path)
            }
            if let strongest = nearby.first { identified.insert(strongest.ide) }
        }
        if identified.isEmpty {
            add(.intellij, folder, "JetBrains project", "Found \(directory.relativePath); JetBrains product is unspecified.", 79)
        } else {
            for ide in identified {
                add(ide, folder, "\(ide.displayName) project", "JetBrains configuration and project evidence in \(directory.relativePath).", 96)
            }
        }
    }

    func enclosingProject(for entry: ScanEntry, names: Set<String>) -> URL {
        let ancestors = entries.filter {
            !$0.isDirectory && names.contains($0.lowerName) && entry.url.path.hasPrefix($0.parent.path + "/")
        }.map(\.parent)
        // Prefer the outer Gradle root so multi-module Android projects load together.
        return ancestors.min { $0.pathComponents.count < $1.pathComponents.count } ?? root
    }

    mutating func detectSourceLanguages() {
        var extensions: Set<String> = []
        for entry in entries where !entry.isDirectory { extensions.insert(entry.ext) }
        let groups: [(Set<String>, IDEID, String)] = [
            (["swift", "mm"], .xcode, "Apple source"),
            (["py", "ipynb"], .pycharm, "Python"),
            (["java", "kt", "kts", "scala"], .intellij, "JVM source"),
            (["js", "jsx", "ts", "tsx", "vue", "svelte", "html", "css"], .webstorm, "Web source"),
            (["php"], .phpstorm, "PHP"), (["rb", "erb"], .rubymine, "Ruby"),
            (["go"], .goland, "Go"), (["rs"], .rustrover, "Rust"),
            (["c", "cc", "cpp", "cxx", "h", "hpp"], .clion, "C / C++"),
            (["cs", "fs", "vb"], .rider, ".NET source"), (["r", "rmd"], .rstudio, "R")
        ]
        for (matching, ide, kind) in groups where !matching.isDisjoint(with: extensions) {
            let found = matching.intersection(extensions).sorted().map { ".\($0)" }.joined(separator: ", ")
            let target = ide == .xcode ? entries.first(where: { !$0.isDirectory && matching.contains($0.ext) })?.url ?? root : root
            add(ide, target, kind, "Found \(found) source files; editor preference is unknown.", 45)
            add(.vscode, root, kind, "Found \(found) source files; compatible general-purpose editor.", 40)
        }
        let generalPurposeLanguages: [(Set<String>, String)] = [
            (["ex", "exs"], "Elixir"), (["hs", "lhs"], "Haskell"), (["jl"], "Julia"),
            (["tf", "tfvars"], "Terraform"), (["lua"], "Lua"), (["sh", "bash", "zsh"], "Shell"),
            (["zig"], "Zig"), (["dart"], "Dart"), (["sql"], "SQL"), (["tex"], "LaTeX")
        ]
        for (matching, kind) in generalPurposeLanguages where !matching.isDisjoint(with: extensions) {
            add(.vscode, root, kind, "Found \(kind) source files; compatible general-purpose editor.", 40)
        }
        // .m is shared by Objective-C and MATLAB; inspect bounded text before choosing Xcode.
        for entry in entries where !entry.isDirectory && entry.ext == "m" {
            let text = content(entry)
            if text.contains("#import") || text.contains("@implementation") || text.contains("@interface") {
                add(.xcode, entry.url, "Objective-C", "Objective-C declarations in \(entry.relativePath).", 45)
                break
            }
        }
    }
}
