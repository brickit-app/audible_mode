//
//  CurrentProfileStreamHandler.swift
//  audible_mode
//
//  Created by Andrea Mainella on 03/04/24.
//

import Foundation
import Mute
import Flutter

public class CurrentProfileStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        Mute.shared.notify = { [weak self] muted in
            guard let self else { return }
            DispatchQueue.main.async {
                if muted {
                    self.eventSink?(AudibleProfile.SILENT_MODE.rawValue)
                } else {
                    self.eventSink?(AudibleProfile.NORMAL_MODE.rawValue)
                }
            }
        }
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
