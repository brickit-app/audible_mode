import Foundation

/// Runs `work` on the main thread. State for stream subscriptions is only
/// mutated there, so a callback posted from an audio or notification thread
/// cannot race a cancel or engine detach.
func onMain(_ work: () -> Void) {
    if Thread.isMainThread {
        work()
    } else {
        DispatchQueue.main.sync(execute: work)
    }
}
