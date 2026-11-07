import Foundation
import Observation
import TwigCore

/// Git runs independently from discovery so a slow checkout never delays the menu.
@MainActor
@Observable
final class WorktreeGitStatusStore {
    private(set) var results: [String: GitStatusResult] = [:]
    @ObservationIgnored private var folders: [String: URL] = [:]
    @ObservationIgnored private var pending: Set<String> = []
    @ObservationIgnored private var active: Set<String> = []
    @ObservationIgnored private var isVisible = false
    @ObservationIgnored private var worker: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()

    func update(_ items: [ScannedWorktree]) {
        let current = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.worktree.folder) })
        let ids = Set(current.keys)
        pending.formIntersection(ids)
        pending.formUnion(current.keys.filter { folders[$0] != current[$0] })
        results = results.filter { ids.contains($0.key) }
        folders = current
    }

    func invalidate(ids: Set<String>, all: Bool) {
        pending.formUnion(all ? Set(folders.keys) : ids.intersection(folders.keys))
        schedule()
    }

    func setVisible(_ visible: Bool) {
        guard visible != isVisible else { return }
        isVisible = visible
        if visible {
            // Retry unavailable results on presentation, without an idle polling timer.
            pending.formUnion(folders.keys.filter { results[$0] == nil || results[$0] == .unavailable })
            schedule()
        } else {
            pending.formUnion(active)
            generation = UUID()
            worker?.cancel()
            worker = nil
            active = []
        }
    }

    private func schedule() {
        guard isVisible, worker == nil, !pending.isEmpty else { return }
        let batch = folders.filter { pending.contains($0.key) }
        pending.subtract(batch.keys)
        guard !batch.isEmpty else { return }
        active = Set(batch.keys)
        let token = UUID()
        generation = token
        worker = Task { [weak self] in
            await GitStatusBatch.read(batch) { [weak self] id, status in
                await self?.receive(status, for: id, generation: token)
            }
            guard let self, self.generation == token else { return }
            self.active = []
            self.worker = nil
            self.schedule()
        }
    }

    private func receive(_ status: GitStatusResult, for id: String, generation token: UUID) {
        guard token == generation, folders[id] != nil else { return }
        active.remove(id)
        // A newer filesystem event wins over an in-flight result.
        guard !pending.contains(id) else { return }
        results[id] = status
    }
}

private enum GitStatusBatch {
    /// This nonisolated async function and its child tasks execute off the main actor.
    static func read(_ folders: [String: URL],
                     onResult: @escaping @Sendable (String, GitStatusResult) async -> Void) async {
        await withTaskGroup(of: (String, GitStatusResult).self) { group in
            var remaining = folders.sorted { $0.key < $1.key }.makeIterator()
            for _ in 0..<min(4, folders.count) {
                guard let (id, folder) = remaining.next() else { break }
                group.addTask { (id, GitStatusReader().read(at: folder)) }
            }
            while let (id, result) = await group.next() {
                guard !Task.isCancelled else { group.cancelAll(); return }
                await onResult(id, result)
                if let (nextID, folder) = remaining.next() {
                    group.addTask { (nextID, GitStatusReader().read(at: folder)) }
                }
            }
        }
    }
}
