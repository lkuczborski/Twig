import Darwin
import Foundation

struct GitProcessOutput {
    let exitCode: Int32
    let data: Data
}

/// A small synchronous runner for background callers. Both pipes are nonblocking,
/// and a separate process group lets a deadline also stop inherited child processes.
enum BoundedGitProcess {
    static func run(
        executable: String = "/usr/bin/git",
        arguments: [String],
        environment: [String: String],
        input: Data = Data(),
        deadline: ContinuousClock.Instant,
        maximumOutputBytes: Int
    ) -> GitProcessOutput? {
        guard maximumOutputBytes >= 0, !Task.isCancelled, ContinuousClock.now < deadline else { return nil }
        var outputPipe: [Int32] = [0, 0]
        var inputPipe: [Int32] = [0, 0]
        guard pipe(&outputPipe) == 0 else { return nil }
        guard pipe(&inputPipe) == 0 else {
            close(outputPipe[0]); close(outputPipe[1])
            return nil
        }
        let null = open("/dev/null", O_RDWR)
        guard null >= 0 else {
            for fd in outputPipe + inputPipe { close(fd) }
            return nil
        }
        defer { close(outputPipe[0]); close(inputPipe[1]); close(null) }

        var actions: posix_spawn_file_actions_t?
        var attributes: posix_spawnattr_t?
        posix_spawn_file_actions_init(&actions)
        posix_spawnattr_init(&attributes)
        defer { posix_spawn_file_actions_destroy(&actions); posix_spawnattr_destroy(&attributes) }
        posix_spawn_file_actions_adddup2(&actions, inputPipe[0], STDIN_FILENO)
        posix_spawn_file_actions_adddup2(&actions, outputPipe[1], STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&actions, null, STDERR_FILENO)
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT))
        posix_spawnattr_setpgroup(&attributes, 0)

        let argv = ([executable] + arguments).map { strdup($0) } + [nil]
        let envp = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer {
            for pointer in argv + envp { free(pointer) }
        }
        var pid: pid_t = 0
        let launchResult = argv.withUnsafeBufferPointer { arguments in
            envp.withUnsafeBufferPointer { environment in
                posix_spawn(&pid, executable, &actions, &attributes, arguments.baseAddress!, environment.baseAddress!)
            }
        }
        close(outputPipe[1]); close(inputPipe[0])
        guard launchResult == 0 else { return nil }
        _ = fcntl(outputPipe[0], F_SETFL, O_NONBLOCK)
        _ = fcntl(inputPipe[1], F_SETFL, O_NONBLOCK)
        _ = fcntl(inputPipe[1], F_SETNOSIGPIPE, 1)
        var reaped = false
        var succeeded = false
        defer {
            if !succeeded { kill(-pid, SIGKILL) }
            if !reaped {
                // Reap off the calling thread: even a kernel-stalled child cannot
                // turn the public reader's deadline into an unbounded wait.
                kill(-pid, SIGKILL)
                kill(pid, SIGKILL)
                let child = pid
                DispatchQueue.global(qos: .utility).async {
                    var status: Int32 = 0
                    while waitpid(child, &status, 0) < 0 && errno == EINTR {}
                }
            }
        }
        var output = Data()
        var buffer = [UInt8](repeating: 0, count: 16_384)
        var inputOffset = 0
        var inputClosed = false
        var outputClosed = false
        var status: Int32 = 0

        while ContinuousClock.now < deadline && !Task.isCancelled {
            if !inputClosed {
                if inputOffset == input.count {
                    // dup2 /dev/null retains a valid descriptor for the final defer.
                    _ = dup2(null, inputPipe[1])
                    inputClosed = true
                } else {
                    let written = input.withUnsafeBytes { bytes in
                        Darwin.write(inputPipe[1], bytes.baseAddress!.advanced(by: inputOffset), input.count - inputOffset)
                    }
                    if written > 0 { inputOffset += written }
                    else if written < 0 && errno != EAGAIN && errno != EINTR { return nil }
                }
            }
            // One read per iteration keeps deadline/cancellation checks responsive
            // even if a process produces a continuous stream of output.
            if !outputClosed {
                let count = Darwin.read(outputPipe[0], &buffer, buffer.count)
                if count > 0 {
                    guard count <= maximumOutputBytes - output.count else { return nil }
                    output.append(contentsOf: buffer.prefix(count))
                } else if count == 0 { outputClosed = true }
                else if errno != EAGAIN && errno != EINTR { return nil }
            }
            if !reaped {
                let result = waitpid(pid, &status, WNOHANG)
                if result == pid { reaped = true }
                else if result < 0 && errno != EINTR { return nil }
            }
            if reaped && outputClosed {
                guard status & 0x7f == 0 else { return nil }
                succeeded = true
                return GitProcessOutput(exitCode: (status >> 8) & 0xff, data: output)
            }
            var descriptors = [pollfd(fd: outputClosed ? -1 : outputPipe[0], events: Int16(POLLIN), revents: 0),
                               pollfd(fd: inputClosed ? -1 : inputPipe[1], events: Int16(POLLOUT), revents: 0)]
            _ = poll(&descriptors, nfds_t(descriptors.count), 10)
        }
        // The parent might have exited while a child still owns stdout.
        kill(-pid, SIGKILL)
        return nil
    }
}
