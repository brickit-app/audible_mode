import Foundation

protocol VolumeNotificationCenter: AnyObject {
    func addObserver(
        forName name: Notification.Name?,
        object obj: Any?,
        queue: OperationQueue?,
        using block: @escaping (Notification) -> Void
    ) -> NSObjectProtocol

    func removeObserver(_ observer: Any)
}

/// Forwards to `NotificationCenter` without redeclaring its method as a protocol
/// witness. The system method's sendability annotation does not match a plain
/// Swift protocol requirement.
final class SystemVolumeNotificationCenter: VolumeNotificationCenter {
    private let center: NotificationCenter

    init(_ center: NotificationCenter = .default) {
        self.center = center
    }

    func addObserver(
        forName name: Notification.Name?,
        object obj: Any?,
        queue: OperationQueue?,
        using block: @escaping (Notification) -> Void
    ) -> NSObjectProtocol {
        center.addObserver(forName: name, object: obj, queue: queue, using: block)
    }

    func removeObserver(_ observer: Any) {
        center.removeObserver(observer)
    }
}
