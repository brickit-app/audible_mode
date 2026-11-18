import Foundation

/// Detach order: drop native callbacks and sinks first, then run the channel
/// unhook. A second call is a no-op.
///
/// The iOS plugin passes an empty unhook. `detachFromEngineForRegistrar:`
/// runs only from `FlutterEngine` dealloc, after the weak messenger parent
/// has already been cleared.
final class PluginLifecycle {
    private let subscriptions: AudibleNativeSubscriptions
    private let detachChannels: () -> Void
    private var disposed = false

    init(subscriptions: AudibleNativeSubscriptions, detachChannels: @escaping () -> Void) {
        self.subscriptions = subscriptions
        self.detachChannels = detachChannels
    }

    /// Stops observers and drops sinks without touching the messenger.
    /// `destroyContext` leaves the engine object alive, so channel handlers
    /// must stay in place for a later listen.
    func invalidateSubscriptions() {
        onMain {
            self.subscriptions.invalidate()
        }
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
