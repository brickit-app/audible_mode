import Foundation

private var failures: [String] = []

private func check(
    _ condition: @autoclosure () -> Bool,
    _ message: String,
    file: StaticString = #file,
    line: UInt = #line
) {
    if !condition() {
        failures.append("\(file):\(line): \(message)")
    }
}

private func pumpMain(until condition: () -> Bool, timeout: TimeInterval = 1) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition(), Date() < deadline {
        CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0.01, true)
    }
    return condition()
}

/// Waits until work already queued on the main queue, and this marker, has run.
private func flushMain() {
    var flushed = false
    DispatchQueue.main.async {
        flushed = true
    }
    check(pumpMain { flushed }, "main queue did not flush")
}

private final class RecordingNotificationCenter: VolumeNotificationCenter {
    private(set) var addCount = 0
    private(set) var removeCount = 0
    private var blocks: [ObjectIdentifier: (Notification.Name?, (Notification) -> Void)] = [:]

    var observerCount: Int { blocks.count }

    func addObserver(
        forName name: Notification.Name?,
        object obj: Any?,
        queue: OperationQueue?,
        using block: @escaping (Notification) -> Void
    ) -> NSObjectProtocol {
        addCount += 1
        let token = NSObject()
        blocks[ObjectIdentifier(token)] = (name, block)
        return token
    }

    func removeObserver(_ observer: Any) {
        removeCount += 1
        guard let object = observer as? NSObject else {
            return
        }
        blocks[ObjectIdentifier(object)] = nil
    }

    func post(name: Notification.Name, volume: Float) {
        let notification = Notification(
            name: name,
            object: nil,
            userInfo: [Constants.VOLUME_NOTIFICATION_PARAM: volume]
        )
        for (registeredName, block) in blocks.values {
            if registeredName == nil || registeredName == name {
                block(notification)
            }
        }
    }
}

private final class RecordingMute: MuteSwitchNotifying {
    private var stored: ((Bool) -> Void)?
    private(set) var nilAssignments = 0

    var notify: ((Bool) -> Void)? {
        get { stored }
        set {
            if newValue == nil {
                nilAssignments += 1
            }
            stored = newValue
        }
    }

    /// Matches Mute: the queued block reads `notify` when it runs, not when it is scheduled.
    func enqueue(_ muted: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.notify?(muted)
        }
    }
}

private let volumeName = Notification.Name("audible_mode.test.volume")

private func makeVolume(center: RecordingNotificationCenter) -> VolumeObservation {
    VolumeObservation(
        center: center,
        notificationName: volumeName,
        volumeKey: Constants.VOLUME_NOTIFICATION_PARAM
    )
}

private func testVolumeListenDeliversEvent() {
    let center = RecordingNotificationCenter()
    let volume = makeVolume(center: center)
    var values: [Double] = []
    volume.start { values.append($0) }
    center.post(name: volumeName, volume: 0.5)
    center.post(name: volumeName, volume: 0.25)
    check(pumpMain { values.count == 2 }, "volume events were not delivered")
    check(values == [0.5, 0.25], "delivered \(values)")
}

private func testVolumeCancelDropsLaterEvents() {
    let center = RecordingNotificationCenter()
    let volume = makeVolume(center: center)
    var values: [Double] = []
    volume.start { values.append($0) }
    volume.stop()
    center.post(name: volumeName, volume: 0.5)
    flushMain()
    check(values.isEmpty, "event delivered after cancel: \(values)")
    check(!volume.isObserving, "observer still registered after cancel")
}

private func testVolumeRelistenDoesNotDuplicateObservers() {
    let center = RecordingNotificationCenter()
    let volume = makeVolume(center: center)
    var values: [Double] = []
    volume.start { values.append($0) }
    volume.start { values.append($0) }
    check(center.addCount == 2, "adds \(center.addCount)")
    check(center.removeCount == 1, "removes \(center.removeCount)")
    check(center.observerCount == 1, "observers \(center.observerCount)")
    center.post(name: volumeName, volume: 0.5)
    check(pumpMain { values.count == 1 }, "expected one event, got \(values)")
}

private func testVolumeQueuedCallbackIsDroppedAfterCancel() {
    let center = RecordingNotificationCenter()
    let volume = makeVolume(center: center)
    var values: [Double] = []
    volume.start { values.append($0) }
    center.post(name: volumeName, volume: 0.5)
    volume.stop()
    flushMain()
    check(values.isEmpty, "queued callback delivered after cancel: \(values)")
}

private func testVolumeOldCallbackDoesNotReachNewSink() {
    let center = RecordingNotificationCenter()
    let volume = makeVolume(center: center)
    var first: [Double] = []
    var second: [Double] = []
    volume.start { first.append($0) }
    center.post(name: volumeName, volume: 0.5)
    volume.stop()
    volume.start { second.append($0) }
    flushMain()
    check(first.isEmpty, "old sink received \(first)")
    check(second.isEmpty, "new sink received stale callback \(second)")
    center.post(name: volumeName, volume: 0.25)
    check(pumpMain { second == [0.25] }, "new listen did not deliver, got \(second)")
    check(first.isEmpty, "old sink received \(first) after relisten")
}

private func testVolumeStopIsIdempotent() {
    let center = RecordingNotificationCenter()
    let volume = makeVolume(center: center)
    volume.stop()
    volume.stop()
    volume.start { _ in }
    volume.stop()
    volume.stop()
    check(center.removeCount == 1, "removes \(center.removeCount)")
    check(center.observerCount == 0, "observers \(center.observerCount)")
    check(!volume.isObserving, "still observing")
}

private func testVolumeStartFromBackgroundQueue() {
    let center = RecordingNotificationCenter()
    let volume = makeVolume(center: center)
    var started = false
    DispatchQueue.main.async {
        DispatchQueue.global(qos: .userInitiated).async {
            volume.start { _ in }
            DispatchQueue.main.async {
                started = true
            }
        }
    }
    check(pumpMain { started && volume.isObserving }, "background start did not observe")
    volume.stop()
}

private func testProfileListenDeliversEvent() {
    let mute = RecordingMute()
    let profile = ProfileObservation(mute: mute)
    var values: [Bool] = []
    profile.start { values.append($0) }
    check(pumpMain { profile.isArmed }, "profile listen did not arm")
    mute.notify?(true)
    check(pumpMain { values == [true] }, "delivered \(values)")
    mute.notify?(false)
    check(pumpMain { values == [true, false] }, "delivered \(values)")
}

private func testProfileCancelDropsLaterEvents() {
    let mute = RecordingMute()
    let profile = ProfileObservation(mute: mute)
    var values: [Bool] = []
    profile.start { values.append($0) }
    check(pumpMain { profile.isArmed }, "profile listen did not arm")
    profile.stop()
    mute.notify?(true)
    mute.enqueue(false)
    flushMain()
    check(values.isEmpty, "event delivered after cancel: \(values)")
    check(!profile.isActive, "sink still active after cancel")
    check(mute.notify == nil, "mute callback still installed")
}

private func testProfileQueuedMuteCallbackIsDroppedAfterCancel() {
    let mute = RecordingMute()
    let profile = ProfileObservation(mute: mute)
    var values: [Bool] = []
    profile.start { values.append($0) }
    check(pumpMain { profile.isArmed }, "profile listen did not arm")
    mute.notify?(true)
    profile.stop()
    flushMain()
    check(values.isEmpty, "queued profile callback delivered after cancel: \(values)")
}

private func testProfileAlreadyQueuedMuteLookupMissesNewSubscription() {
    let mute = RecordingMute()
    let profile = ProfileObservation(mute: mute)
    var first: [Bool] = []
    var second: [Bool] = []
    profile.start { first.append($0) }
    check(pumpMain { profile.isArmed }, "profile listen did not arm")
    mute.enqueue(true)
    profile.stop()
    profile.start { second.append($0) }
    check(pumpMain { profile.isArmed }, "second listen did not arm")
    check(first.isEmpty, "old sink received \(first)")
    check(second.isEmpty, "stale mute lookup reached the new sink \(second)")
    mute.notify?(false)
    check(pumpMain { second == [false] }, "new listen did not deliver, got \(second)")
    check(first.isEmpty, "old sink received \(first) after relisten")
}

private func testProfileStopIsIdempotent() {
    let mute = RecordingMute()
    let profile = ProfileObservation(mute: mute)
    profile.stop()
    profile.stop()
    profile.start { _ in }
    check(pumpMain { profile.isArmed }, "profile listen did not arm")
    let nilCountAfterStart = mute.nilAssignments
    profile.stop()
    profile.stop()
    check(mute.nilAssignments == nilCountAfterStart + 1, "nil assignments \(mute.nilAssignments)")
    check(mute.notify == nil, "callback still installed")
    check(!profile.isActive, "still active")
}

private func testDetachWithoutCancelClearsBothSubscriptionsAndIsIdempotent() {
    let center = RecordingNotificationCenter()
    let mute = RecordingMute()
    let volume = makeVolume(center: center)
    let profile = ProfileObservation(mute: mute)
    let subscriptions = AudibleNativeSubscriptions(volume: volume, profile: profile)
    var channelDetaches = 0
    var volumeEvents: [Double] = []
    var profileEvents: [Bool] = []
    let lifecycle = PluginLifecycle(subscriptions: subscriptions) {
        check(!volume.isObserving, "volume observer still installed at channel detach")
        check(!profile.isActive, "profile sink still installed at channel detach")
        check(mute.notify == nil, "mute callback still installed at channel detach")
        channelDetaches += 1
    }

    volume.start { volumeEvents.append($0) }
    profile.start { profileEvents.append($0) }
    check(pumpMain { profile.isArmed }, "profile listen did not arm")
    center.post(name: volumeName, volume: 0.5)
    mute.notify?(true)
    mute.enqueue(false)
    lifecycle.dispose()
    lifecycle.dispose()
    flushMain()

    check(channelDetaches == 1, "channel detach count \(channelDetaches)")
    check(volumeEvents.isEmpty, "volume delivered after detach \(volumeEvents)")
    check(profileEvents.isEmpty, "profile delivered after detach \(profileEvents)")
    check(!volume.isObserving, "volume observer survived detach")
    check(!profile.isActive, "profile sink survived detach")
    check(center.observerCount == 0, "volume observers \(center.observerCount)")
    check(mute.notify == nil, "mute callback survived detach")
}

let tests: [() -> Void] = [
    testVolumeListenDeliversEvent,
    testVolumeCancelDropsLaterEvents,
    testVolumeRelistenDoesNotDuplicateObservers,
    testVolumeQueuedCallbackIsDroppedAfterCancel,
    testVolumeOldCallbackDoesNotReachNewSink,
    testVolumeStopIsIdempotent,
    testVolumeStartFromBackgroundQueue,
    testProfileListenDeliversEvent,
    testProfileCancelDropsLaterEvents,
    testProfileQueuedMuteCallbackIsDroppedAfterCancel,
    testProfileAlreadyQueuedMuteLookupMissesNewSubscription,
    testProfileStopIsIdempotent,
    testDetachWithoutCancelClearsBothSubscriptionsAndIsIdempotent,
]

for test in tests {
    test()
}

if failures.isEmpty {
    print("Passed \(tests.count) iOS lifecycle tests")
} else {
    for failure in failures {
        print(failure)
    }
    print("Failed \(failures.count) assertion(s)")
    exit(1)
}
