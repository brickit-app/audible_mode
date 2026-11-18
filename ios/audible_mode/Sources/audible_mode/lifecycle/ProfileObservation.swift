import Foundation

/// Silent-mode notifications for one event-channel subscription.
///
/// `Mute` reads `notify` when a block that is already queued on the main queue
/// runs, so replacing the closure does not by itself stop that in-flight call
/// from entering the new subscription. A listen therefore stays disarmed until
/// the next main-queue turn, after those already-queued calls have run. The
/// callback that then hops to the main queue checks the generation again
/// immediately before touching the sink.
final class ProfileObservation {
    private let mute: MuteSwitchNotifying
    private var generation: UInt = 0
    private var armedGeneration: UInt = 0
    private var sink: ((Bool) -> Void)?
    private var ownsNotify = false

    init(mute: MuteSwitchNotifying) {
        self.mute = mute
    }

    var isActive: Bool {
        var active = false
        onMain {
            active = self.sink != nil
        }
        return active
    }

    var isArmed: Bool {
        var armed = false
        onMain {
            armed = self.armedGeneration != 0 && self.armedGeneration == self.generation
        }
        return armed
    }

    func start(sink: @escaping (Bool) -> Void) {
        onMain {
            self.stopOnMain()
            self.generation &+= 1
            let generation = self.generation
            self.sink = sink
            self.installNotify()
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == generation else {
                    return
                }
                self.armedGeneration = generation
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
        armedGeneration = 0
        sink = nil
        guard ownsNotify else {
            return
        }
        ownsNotify = false
        mute.notify = nil
    }

    private func installNotify() {
        ownsNotify = true
        mute.notify = { [weak self] muted in
            self?.handleMute(muted)
        }
    }

    private func handleMute(_ muted: Bool) {
        let forward = { [weak self] in
            guard let self else {
                return
            }
            let generation = self.armedGeneration
            guard generation != 0, generation == self.generation else {
                return
            }
            DispatchQueue.main.async { [weak self] in
                self?.emit(muted, generation: generation)
            }
        }
        if Thread.isMainThread {
            forward()
        } else {
            DispatchQueue.main.async(execute: forward)
        }
    }

    private func emit(_ muted: Bool, generation: UInt) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard self.generation == generation, let sink else {
            return
        }
        sink(muted)
    }
}
