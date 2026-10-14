import Foundation

/// Detach order: drop native callbacks and sinks first, then unhook channels.
/// A second call is a no-op.
final class PluginLifecycle {
    private let subscriptions: AudibleNativeSubscriptions
    private let detachChannels: () -> Void
    private var disposed = false

    init(subscriptions: AudibleNativeSubscriptions, detachChannels: @escaping () -> Void) {
        self.subscriptions = subscriptions
        self.detachChannels = detachChannels
    }

    func dispose() {
        onMain {
            guard !self.disposed else {
                return
            }
            self.disposed = true
            self.subscriptions.invalidate()
            self.detachChannels()
        }
    }
}
