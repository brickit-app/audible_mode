import Foundation
import Flutter
import Mute

public class FlutterHandler {
    private let channel: FlutterMethodChannel
    private let currentProfileEventChannel: FlutterEventChannel
    private let currentVolumeEventChannel: FlutterEventChannel
    private let currentVolumeHandler: CurrentVolumeStreamHandler
    private let currentProfileHandler: CurrentProfileStreamHandler
    private let lifecycle: PluginLifecycle

    init(binding: FlutterPluginRegistrar) {
        let audibleHandler = AudibleHandler()
        let subscriptions = AudibleNativeSubscriptions(
            volume: VolumeObservation(),
            profile: ProfileObservation(mute: Mute.shared)
        )

        let methodChannel = FlutterMethodChannel(
            name: Constants.METHOD_CHANNEL,
            binaryMessenger: binding.messenger()
        )
        let profileChannel = FlutterEventChannel(
            name: Constants.CURRENT_PROFILE_EVENT,
            binaryMessenger: binding.messenger()
        )
        let volumeChannel = FlutterEventChannel(
            name: Constants.CURRENT_VOLUME_EVENT,
            binaryMessenger: binding.messenger()
        )

        channel = methodChannel
        currentProfileEventChannel = profileChannel
        currentVolumeEventChannel = volumeChannel
        lifecycle = PluginLifecycle(subscriptions: subscriptions) {
            methodChannel.setMethodCallHandler(nil)
            profileChannel.setStreamHandler(nil)
            volumeChannel.setStreamHandler(nil)
        }
        currentVolumeHandler = CurrentVolumeStreamHandler(volumeChannel, volume: subscriptions.volume)
        currentProfileHandler = CurrentProfileStreamHandler(profile: subscriptions.profile)

        methodChannel.setMethodCallHandler { (call: FlutterMethodCall, result: FlutterResult) -> Void in
            switch call.method {
            case Constants.GET_AUDIBLE_MODE:
                result(audibleHandler.getAudibleProfile())
            case Constants.GET_CURRENT_VOLUME:
                result(audibleHandler.getCurrentVolume())
            case Constants.SET_VOLUME:
                if let args = call.arguments as? Dictionary<String, Any> {
                    audibleHandler.setVolume(volume: (args["volume"] as? NSNumber)?.floatValue)
                }
                result(true)
            case Constants.GET_MAX_VOLUME:
                result(audibleHandler.getMaxVolume())
            default:
                result("Method not found")
            }
        }
        profileChannel.setStreamHandler(currentProfileHandler)
    }

    public func dispose() {
        lifecycle.dispose()
    }

    deinit {
        let lifecycle = lifecycle
        if Thread.isMainThread {
            lifecycle.dispose()
        } else {
            DispatchQueue.main.async {
                lifecycle.dispose()
            }
        }
    }
}
