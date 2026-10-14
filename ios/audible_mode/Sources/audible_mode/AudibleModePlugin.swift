import Flutter

public class AudibleModePlugin: NSObject, FlutterPlugin {
    private var flutterHandler: FlutterHandler?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = AudibleModePlugin()
        instance.flutterHandler = FlutterHandler(binding: registrar)
        // FlutterEngine calls detachFromEngineForRegistrar: only for instances
        // stored via publish. Declaring the method without publishing never runs it.
        registrar.publish(instance)
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
