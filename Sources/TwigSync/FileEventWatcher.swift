import CoreServices
import Foundation

public struct FilesystemEvent: Sendable, Equatable {
    public let path: String
    public let requiresFullRescan: Bool

    public init(path: String, requiresFullRescan: Bool = false) {
        self.path = path
        self.requiresFullRescan = requiresFullRescan
    }
}

public enum WatcherError: LocalizedError {
    case cannotCreate, cannotStart
    public var errorDescription: String? {
        switch self {
        case .cannotCreate: "Could not create filesystem notifications. Refresh manually with ⌘R."
        case .cannotStart: "Could not start filesystem notifications. Refresh manually with ⌘R."
        }
    }
}

/// FSEvents batches directory changes rather than waking on a repeating timer.
/// Stream lifetime is confined to one queue. Callback context is immutable and retained by CoreServices.
public final class FileEventWatcher: @unchecked Sendable {
    private let queue = DispatchQueue(label: "dev.twig.filesystem", qos: .utility)
    private var stream: FSEventStreamRef?

    public init() {}
    deinit { stop() }

    public static var currentEventID: UInt64 { FSEventsGetCurrentEventId() }

    public func start(
        paths: [URL], since eventID: UInt64? = nil,
        latency: TimeInterval = 1,
        onChange: @escaping @Sendable ([FilesystemEvent]) -> Void
    ) throws {
        try queue.sync {
            stopOnQueue()
            let paths = Self.minimalRoots(paths).map(\.path)
            guard !paths.isEmpty else { return }
            let callback = WatcherCallback(onChange)
            var context = FSEventStreamContext(
                version: 0,
                info: Unmanaged.passUnretained(callback).toOpaque(),
                retain: { pointer in
                    guard let pointer else { return nil }
                    _ = Unmanaged<WatcherCallback>.fromOpaque(pointer).retain()
                    return pointer
                },
                release: { pointer in
                    guard let pointer else { return }
                    Unmanaged<WatcherCallback>.fromOpaque(pointer).release()
                },
                copyDescription: nil
            )
            let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagWatchRoot)
            guard let created = FSEventStreamCreate(
                kCFAllocatorDefault, filesystemCallback, &context, paths as CFArray,
                eventID ?? UInt64(kFSEventStreamEventIdSinceNow), latency, flags
            ) else { throw WatcherError.cannotCreate }
            FSEventStreamSetDispatchQueue(created, queue)
            guard FSEventStreamStart(created) else {
                FSEventStreamInvalidate(created)
                FSEventStreamRelease(created)
                throw WatcherError.cannotStart
            }
            stream = created
        }
    }

    public func stop() { queue.sync { stopOnQueue() } }

    private func stopOnQueue() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    /// A missing root is watched through its closest existing parent so its creation is observed.
    public static func existingWatchRoot(for url: URL) -> URL {
        var candidate = url.standardizedFileURL.resolvingSymlinksInPath()
        var directory: ObjCBool = false
        while !FileManager.default.fileExists(atPath: candidate.path, isDirectory: &directory) || !directory.boolValue {
            let parent = candidate.deletingLastPathComponent()
            if parent.path == candidate.path { break }
            candidate = parent
        }
        return candidate
    }

    public static func minimalRoots(_ urls: [URL]) -> [URL] {
        let sorted = Set(urls.filter(\.isFileURL).map {
            $0.standardizedFileURL.resolvingSymlinksInPath().path
        }).sorted { $0.count == $1.count ? $0 < $1 : $0.count < $1.count }
        var paths: [String] = []
        for path in sorted where !paths.contains(where: { isWithin(path, root: $0) }) { paths.append(path) }
        return paths.map { URL(fileURLWithPath: $0, isDirectory: true) }
    }
}

private final class WatcherCallback: Sendable {
    let handle: @Sendable ([FilesystemEvent]) -> Void
    init(_ handle: @escaping @Sendable ([FilesystemEvent]) -> Void) { self.handle = handle }
}

private let filesystemCallback: FSEventStreamCallback = { _, info, count, paths, flags, _ in
    guard let info else { return }
    let callback = Unmanaged<WatcherCallback>.fromOpaque(info).takeUnretainedValue()
    let array = Unmanaged<CFArray>.fromOpaque(paths).takeUnretainedValue() as NSArray
    let rescanMask = UInt32(kFSEventStreamEventFlagUserDropped
        | kFSEventStreamEventFlagKernelDropped | kFSEventStreamEventFlagRootChanged
        | kFSEventStreamEventFlagEventIdsWrapped | kFSEventStreamEventFlagMount | kFSEventStreamEventFlagUnmount)
    var events: [FilesystemEvent] = []
    for index in 0..<min(count, array.count) {
        guard flags[index] & UInt32(kFSEventStreamEventFlagHistoryDone) == 0 else { continue }
        guard let path = array[index] as? String else { continue }
        events.append(FilesystemEvent(path: path, requiresFullRescan: flags[index] & rescanMask != 0))
    }
    guard !events.isEmpty else { return }
    // Delivery is off the stream's queue so a consumer may safely stop/reconfigure its watcher.
    DispatchQueue.global(qos: .utility).async { [events] in callback.handle(events) }
}

func canonicalPath(_ path: String) -> String {
    URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
}

func isWithin(_ path: String, root: String) -> Bool {
    path == root || (root == "/" ? path.hasPrefix("/") : path.hasPrefix(root + "/"))
}
