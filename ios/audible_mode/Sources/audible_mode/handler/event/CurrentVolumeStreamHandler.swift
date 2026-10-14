import Foundation
import Flutter

class CurrentVolumeStreamHandler: NSObject, FlutterStreamHandler {
    private let volumeEventChannel: FlutterEventChannel
    private let volume: VolumeObservation

    init(_ eventChannel: FlutterEventChannel, volume: VolumeObservation) {
        self.volumeEventChannel = eventChannel
        self.volume = volume
        super.init()
        volumeEventChannel.setStreamHandler(self)
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        volume.start { value in
            events(value)
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        volume.stop()
        return nil
    }
}
