import Foundation

final class AudibleNativeSubscriptions {
    let volume: VolumeObservation
    let profile: ProfileObservation

    init(volume: VolumeObservation, profile: ProfileObservation) {
        self.volume = volume
        self.profile = profile
    }

    func invalidate() {
        volume.stop()
        profile.stop()
    }
}
