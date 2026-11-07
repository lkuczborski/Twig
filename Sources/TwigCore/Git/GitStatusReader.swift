import Foundation

/// Reads local refs and working files only. Call from a background task.
/// Submodule commit changes count as one path; nested dirty files are excluded.
/// Filtered tracked files return unavailable rather than running project filters
/// or reporting a misleading clean/dirty result with those filters disabled.
public struct GitStatusReader: Sendable {
    public let timeout: TimeInterval
    public let maximumOutputBytes: Int

    /// Invalid limits (including a timeout over 60 seconds) yield unavailable.
    public init(timeout: TimeInterval = 2, maximumOutputBytes: Int = 1_048_576) {
        self.timeout = timeout
        self.maximumOutputBytes = maximumOutputBytes
    }

    public func read(at folder: URL) -> GitStatusResult {
        guard folder.isFileURL, timeout.isFinite, timeout > 0, timeout <= 60, maximumOutputBytes > 0 else { return .unavailable }
        let deadline = ContinuousClock.now.advanced(by: .seconds(timeout))
        let environment = Self.environment(ProcessInfo.processInfo.environment)
        var remainingBytes = maximumOutputBytes
        var arguments = ["--no-pager", "--no-optional-locks", "-C", folder.path,
                         "-c", "core.fsmonitor=false", "-c", "core.hooksPath=/dev/null",
                         "-c", "core.untrackedCache=false", "-c", "diff.external=",
                         "-c", "protocol.allow=never"]
        func run(_ command: [String], input: Data = Data()) -> GitProcessOutput? {
            guard let result = BoundedGitProcess.run(arguments: arguments + command, environment: environment,
                                                    input: input, deadline: deadline, maximumOutputBytes: remainingBytes) else { return nil }
            remainingBytes -= result.data.count
            return result
        }

        // Config inspection itself does not invoke filter commands. Disable every
        // configured driver before any command which could inspect file contents.
        guard let config = run(["config", "--null", "--name-only", "--get-regexp",
                                "^(filter\\..*\\.(clean|smudge|process|required)|diff\\..*\\.textconv)$"]),
              config.exitCode == 0 || config.exitCode == 1 else { return .unavailable }
        for rawKey in config.data.split(separator: 0) {
            guard let key = String(data: rawKey, encoding: .utf8) else { return .unavailable }
            arguments += ["-c", key + (key.hasSuffix(".required") ? "=false" : "=")]
        }

        guard let tracked = run(["ls-files", "--cached", "-z"]), tracked.exitCode == 0 else { return .unavailable }
        if !tracked.data.isEmpty {
            guard let attributes = run(["check-attr", "-z", "--stdin", "filter"], input: tracked.data),
                  attributes.exitCode == 0, Self.hasNoFilters(attributes.data) else { return .unavailable }
        }
        guard let status = run(["status", "--porcelain=v2", "-z", "--branch", "--ahead-behind",
                                "--untracked-files=all", "--ignore-submodules=dirty"]),
              status.exitCode == 0, let parsed = GitStatusParser.parse(status.data) else { return .unavailable }
        return .available(parsed)
    }

    static func environment(_ inherited: [String: String]) -> [String: String] {
        var result = inherited.filter { !$0.key.hasPrefix("GIT_") }
        result["GIT_OPTIONAL_LOCKS"] = "0"
        result["GIT_TERMINAL_PROMPT"] = "0"
        result["GIT_NO_LAZY_FETCH"] = "1"
        result["GIT_ALLOW_PROTOCOL"] = ""
        result["LC_ALL"] = "C"
        result["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin"
        return result
    }

    static func hasNoFilters(_ output: Data) -> Bool {
        guard output.last == 0 else { return false }
        let fields = output.dropLast().split(separator: 0, omittingEmptySubsequences: false)
        guard fields.count.isMultiple(of: 3) else { return false }
        for offset in stride(from: 0, to: fields.count, by: 3) {
            guard !fields[offset].isEmpty, fields[offset + 1].elementsEqual("filter".utf8),
                  fields[offset + 2].elementsEqual("unspecified".utf8) || fields[offset + 2].elementsEqual("unset".utf8) else { return false }
        }
        return true
    }
}
