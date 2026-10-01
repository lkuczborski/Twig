import Foundation

/// NotificationCenter owns the observers; this token removes them when its owner is released.
final class WorkspaceNotifications: @unchecked Sendable {
    private let center: NotificationCenter
    private let tokens: [NSObjectProtocol]

    init(center: NotificationCenter, wakeName: Notification.Name, sleepName: Notification.Name,
         onWake: @escaping @Sendable () -> Void, onSleep: @escaping @Sendable () -> Void) {
        self.center = center
        tokens = [
            center.addObserver(forName: wakeName, object: nil, queue: nil) { _ in onWake() },
            center.addObserver(forName: sleepName, object: nil, queue: nil) { _ in onSleep() }
        ]
    }
    deinit { for token in tokens { center.removeObserver(token) } }
}
