import Flutter
import ObjectiveC

public class AudibleModePlugin: NSObject, FlutterPlugin {
    private var flutterHandler: FlutterHandler?
    private static var destructionHookInstalled = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        installEngineDestructionHook()
        let instance = AudibleModePlugin()
        instance.flutterHandler = FlutterHandler(binding: registrar)
        // FlutterEngine calls detachFromEngineForRegistrar: only for instances
        // stored via publish. Declaring the method without publishing never runs it.
        registrar.publish(instance)
    }

    /// `destroyContext` drops the shell and does not call detach. A volume or
    /// mute callback after that reaches `sendOnChannel` and raises
    /// NSInternalInconsistencyException while the messenger parent is still set.
    private static func installEngineDestructionHook() {
        if destructionHookInstalled {
            return
        }
        let selector = #selector(FlutterEngine.destroyContext)
        guard let method = class_getInstanceMethod(FlutterEngine.self, selector) else {
            preconditionFailure("FlutterEngine.destroyContext is missing")
        }
        let original = method_getImplementation(method)
        typealias DestroyIMP = @convention(c) (AnyObject, Selector) -> Void
        let originalDestroy = unsafeBitCast(original, to: DestroyIMP.self)
        let block: @convention(block) (AnyObject) -> Void = { engine in
            let published = (engine as? FlutterEngine)?.valuePublished(byPlugin: "AudibleModePlugin")
            (published as? AudibleModePlugin)?.invalidateNativeSubscriptions()
            originalDestroy(engine, selector)
        }
        destructionHookInstalled = true
        method_setImplementation(method, imp_implementationWithBlock(block))
    }

    func invalidateNativeSubscriptions() {
        flutterHandler?.invalidateSubscriptions()
    }

    /// Selector must stay `detachFromEngineForRegistrar:`. FlutterEngine dealloc
    /// looks up that selector on the published plugin.
    @objc(detachFromEngineForRegistrar:)
    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        tearDown()
    }

    deinit {
        let handler = flutterHandler
        flutterHandler = nil
        guard let handler else {
            return
        }
        if Thread.isMainThread {
            handler.dispose()
        } else {
            DispatchQueue.main.async {
                handler.dispose()
            }
        }
    }

    private func tearDown() {
        flutterHandler?.dispose()
        flutterHandler = nil
    }
}
