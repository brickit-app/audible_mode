import Foundation

protocol MuteSwitchNotifying: AnyObject {
    var notify: ((Bool) -> Void)? { get set }
}
