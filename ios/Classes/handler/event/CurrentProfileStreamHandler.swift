//
//  CurrentProfileStreamHandler.swift
//  audible_mode
//
//  Created by Andrea Mainella on 03/04/24.
//

import Foundation
import Mute

public class CurrentProfileStreamHandler: NSObject, FlutterStreamHandler {
    private var _eventSink: FlutterEventSink?

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        _eventSink = events
        Mute.shared.notify = { [weak self] muted in
            guard let self = self, let eventSink = self._eventSink else { return }
            DispatchQueue.main.async {
                if muted {
                    eventSink(AudibleProfile.SILENT_MODE.rawValue)
                } else {
                    eventSink(AudibleProfile.NORMAL_MODE.rawValue)
                }
            }
        }
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        _eventSink = nil
        return nil
    }
}

