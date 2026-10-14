import Flutter
import Mute
import XCTest
import audible_mode

final class EngineLifecycleTests: XCTestCase {
    private let volumeChannel = "CURRENT_VOLUME_EVENT"
    private let profileChannel = "CURRENT_PROFILE_EVENT"

    override func setUp() {
        super.setUp()
        AMInstallEngineLifecycleSpies(AudibleModePlugin.self)
        AMResetEventChannelSends()
    }

    func testPublishedPluginReceivesDetachWhenEngineIsReleased() {
        let detachCountBefore = AMDetachCount()
        var engine: FlutterEngine? = startEngine()
        let published = engine?.valuePublished(byPlugin: "AudibleModePlugin")
        XCTAssertTrue(published is AudibleModePlugin)

        engine = nil
        pump()

        XCTAssertEqual(AMDetachCount(), detachCountBefore + 1)
    }

    func testListenCancelAndRelistenDoNotDuplicateVolumeEvents() {
        var engine: FlutterEngine? = startEngine()

        probe(engine!, "listenVolume")
        postVolume(0.5)
        pump()
        XCTAssertEqual(eventSends(volumeChannel), 1)
        XCTAssertEqual(dartCount(engine!, "volumeCount"), 1)

        probe(engine!, "cancelVolume")
        postVolume(0.25)
        pump()
        XCTAssertEqual(eventSends(volumeChannel), 1)
        XCTAssertEqual(dartCount(engine!, "volumeCount"), 1)

        probe(engine!, "listenVolume")
        postVolume(0.75)
        pump()
        XCTAssertEqual(eventSends(volumeChannel), 2)
        XCTAssertEqual(dartCount(engine!, "volumeCount"), 2)
        engine = nil
        pump()
    }

    func testListenCancelAndRelistenDoNotDuplicateProfileEvents() {
        var engine: FlutterEngine? = startEngine()

        probe(engine!, "listenProfile")
        pump()
        XCTAssertNotNil(Mute.shared.notify)
        Mute.shared.notify?(true)
        pump()
        XCTAssertEqual(eventSends(profileChannel), 1)
        XCTAssertEqual(dartCount(engine!, "profileCount"), 1)

        probe(engine!, "cancelProfile")
        XCTAssertNil(Mute.shared.notify)
        Mute.shared.notify?(false)
        pump()
        XCTAssertEqual(eventSends(profileChannel), 1)
        XCTAssertEqual(dartCount(engine!, "profileCount"), 1)

        probe(engine!, "listenProfile")
        pump()
        Mute.shared.notify?(false)
        pump()
        XCTAssertEqual(eventSends(profileChannel), 2)
        XCTAssertEqual(dartCount(engine!, "profileCount"), 2)
        engine = nil
        pump()
    }

    func testQueuedVolumeCallbackAfterCancelDoesNotSend() {
        var engine: FlutterEngine? = startEngine()
        probe(engine!, "listenVolume")

        // The platform cancel handler is itself queued on the main queue, so a
        // volume callback already queued ahead of it still belongs to the
        // active subscription. Once cancel has finished, a later callback must
        // not send.
        postVolume(0.5)
        probe(engine!, "cancelVolume")
        pump()
        XCTAssertEqual(eventSends(volumeChannel), 1)
        XCTAssertEqual(dartCount(engine!, "volumeCount"), 1)

        postVolume(0.25)
        pump()
        XCTAssertEqual(eventSends(volumeChannel), 1)
        XCTAssertEqual(dartCount(engine!, "volumeCount"), 1)
        engine = nil
        pump()
    }

    func testQueuedProfileCallbackAfterCancelDoesNotReachNewListen() {
        var engine: FlutterEngine? = startEngine()
        probe(engine!, "listenProfile")
        pump()

        Mute.shared.notify?(true)
        probe(engine!, "cancelProfile")
        probe(engine!, "listenProfile")
        pump()
        XCTAssertEqual(eventSends(profileChannel), 1)
        XCTAssertEqual(dartCount(engine!, "profileCount"), 1)

        Mute.shared.notify?(false)
        pump()
        XCTAssertEqual(eventSends(profileChannel), 2)
        XCTAssertEqual(dartCount(engine!, "profileCount"), 2)
        engine = nil
        pump()
    }

    func testQueuedCallbackThenEngineReleaseDoesNotSend() {
        var engine: FlutterEngine? = startEngine()
        probe(engine!, "listenVolume")
        probe(engine!, "listenProfile")
        pump()

        postVolume(0.5)
        Mute.shared.notify?(true)
        let detachCountBefore = AMDetachCount()
        engine = nil
        pump()

        XCTAssertEqual(AMDetachCount(), detachCountBefore + 1)
        XCTAssertEqual(eventSends(volumeChannel), 0)
        XCTAssertEqual(eventSends(profileChannel), 0)
        XCTAssertNil(Mute.shared.notify)
    }

    func testDestroyContextThenReleaseCleansObserversWithoutSending() {
        var engine: FlutterEngine? = startEngine()
        probe(engine!, "listenVolume")
        probe(engine!, "listenProfile")
        pump()

        engine?.destroyContext()
        let detachCountBefore = AMDetachCount()
        engine = nil
        pump()
        XCTAssertEqual(AMDetachCount(), detachCountBefore + 1)

        postVolume(0.5)
        Mute.shared.notify?(true)
        pump()
        XCTAssertEqual(eventSends(volumeChannel), 0)
        XCTAssertEqual(eventSends(profileChannel), 0)
    }

    func testNotificationBetweenDestroyContextAndDetachDoesNotSend() {
        var engine: FlutterEngine? = startEngine()
        probe(engine!, "listenVolume")
        probe(engine!, "listenProfile")
        pump()

        engine?.destroyContext()
        postVolume(0.5)
        Mute.shared.notify?(true)
        pump()

        XCTAssertEqual(eventSends(volumeChannel), 0)
        XCTAssertEqual(eventSends(profileChannel), 0)
        engine = nil
        pump()
    }

    func testNewEngineWorksAfterPreviousEngineIsDestroyed() {
        var first: FlutterEngine? = startEngine()
        probe(first!, "listenVolume")
        first?.destroyContext()
        first = nil
        pump()

        var second: FlutterEngine? = startEngine()
        probe(second!, "listenVolume")
        postVolume(0.5)
        pump()
        XCTAssertEqual(eventSends(volumeChannel), 1)
        XCTAssertEqual(dartCount(second!, "volumeCount"), 1)
        second = nil
        pump()
    }

    func testReleasingEngineOffMainDoesNotDeadlock() {
        var engine: FlutterEngine? = startEngine()
        probe(engine!, "listenVolume")
        var escaping: FlutterEngine? = engine
        engine = nil

        let released = expectation(description: "engine released off main")
        DispatchQueue.global(qos: .userInitiated).async {
            escaping = nil
            XCTAssertNil(escaping)
            released.fulfill()
        }
        wait(for: [released], timeout: 3)
        pump()
        postVolume(0.5)
        pump()
        XCTAssertEqual(eventSends(volumeChannel), 0)
    }

    private func startEngine() -> FlutterEngine {
        let engine = FlutterEngine(name: "audible-lifecycle-\(UUID().uuidString)", project: FlutterDartProject())
        XCTAssertTrue(engine.run(withEntrypoint: "engineProbeMain"))
        let ready = expectation(description: "isolate")
        let deadline = Date().addingTimeInterval(20)
        func poll() {
            if engine.isolateId != nil || Date() > deadline {
                ready.fulfill()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: poll)
            }
        }
        poll()
        wait(for: [ready], timeout: 21)
        XCTAssertNotNil(engine.isolateId)

        guard let registrar = engine.registrar(forPlugin: "AudibleModePlugin") else {
            XCTFail("FlutterEngine did not create a registrar")
            return engine
        }
        AudibleModePlugin.register(with: registrar)
        return engine
    }

    private func probe(_ engine: FlutterEngine, _ method: String) -> Any? {
        let channel = FlutterMethodChannel(
            name: "audible_mode_engine_probe",
            binaryMessenger: engine.binaryMessenger
        )
        let replied = expectation(description: method)
        var value: Any?
        channel.invokeMethod(method, arguments: nil) { result in
            value = result
            replied.fulfill()
        }
        wait(for: [replied], timeout: 5)
        if let error = value as? FlutterError {
            XCTFail("\(method) failed: \(error.code) \(error.message ?? "")")
        }
        return value
    }

    private func dartCount(_ engine: FlutterEngine, _ method: String) -> Int {
        (probe(engine, method) as? NSNumber)?.intValue ?? -1
    }

    private func postVolume(_ value: Float) {
        NotificationCenter.default.post(
            name: Notification.Name("SystemVolumeDidChange"),
            object: nil,
            userInfo: ["Volume": value]
        )
    }

    private func pump() {
        let flushed = expectation(description: "main flushed")
        DispatchQueue.main.async {
            flushed.fulfill()
        }
        wait(for: [flushed], timeout: 2)
    }

    private func eventSends(_ channel: String) -> Int {
        AMEventChannelSends().filter { $0 == channel }.count
    }
}
