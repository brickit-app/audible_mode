import Foundation

/// Volume notifications for one event-channel subscription.
///
/// The block-based observer token is retained and removed by that token.
/// `removeObserver(self)` does not remove a block observer. The delayed main-queue
/// callback reads the sink only after checking the subscription generation, so a
/// callback queued by an older `start` cannot emit into a newer sink.
final class VolumeObservation {
    private let center: VolumeNotificationCenter
    private let notificationName: Notification.Name
    private let volumeKey: String
    private var observerToken: NSObjectProtocol?
    private var generation: UInt = 0
    private var sink: ((Double) -> Void)?

    init(
        center: VolumeNotificationCenter = SystemVolumeNotificationCenter(),
        notificationName: Notification.Name = Notification.Name(rawValue: Constants.VOLUME_NOTIFICATION),
        volumeKey: String = Constants.VOLUME_NOTIFICATION_PARAM
    ) {
        self.center = center
        self.notificationName = notificationName
        self.volumeKey = volumeKey
    }

    var isObserving: Bool {
        var observing = false
        onMain {
            observing = self.observerToken != nil
        }
        return observing
    }

    func start(sink: @escaping (Double) -> Void) {
        onMain {
            self.stopOnMain()
            self.generation &+= 1
            let generation = self.generation
            let volumeKey = self.volumeKey
            self.sink = sink
            self.observerToken = self.center.addObserver(
                forName: self.notificationName,
                object: nil,
                queue: nil
            ) { [weak self] notification in
                guard let volume = notification.userInfo?[volumeKey] as? Float else {
                    return
                }
                let value = Double(volume)
                DispatchQueue.main.async { [weak self] in
                    self?.emit(value, generation: generation)
                }
            }
        }
    }

    func stop() {
        onMain {
            self.stopOnMain()
        }
    }

    private func stopOnMain() {
        generation &+= 1
        sink = nil
        if let observerToken {
            center.removeObserver(observerToken)
            self.observerToken = nil
        }
    }

    private func emit(_ value: Double, generation: UInt) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard self.generation == generation, let sink else {
            return
        }
        sink(value)
    }
}
