import Foundation
import Mute
import Flutter

extension Mute: MuteSwitchNotifying {}

public class CurrentProfileStreamHandler: NSObject, FlutterStreamHandler {
    private let profile: ProfileObservation

    init(profile: ProfileObservation) {
        self.profile = profile
        super.init()
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        profile.start { isMuted in
            let value = isMuted
                ? AudibleProfile.SILENT_MODE.rawValue
                : AudibleProfile.NORMAL_MODE.rawValue
            events(value)
        }
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        profile.stop()
        return nil
    }
}
