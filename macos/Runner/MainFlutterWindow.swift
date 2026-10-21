import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    HidPlugin.register(with: flutterViewController.registrar(forPlugin: "HidPlugin"))

    let app = FlutterMethodChannel(name: "openx11se/app", binaryMessenger: flutterViewController.engine.binaryMessenger)
    app.setMethodCallHandler { call, result in
      guard call.method == "setKeepRunningInMenuBar", let enabled = call.arguments as? Bool else {
        result(FlutterMethodNotImplemented)
        return
      }
      (NSApp.delegate as? AppDelegate)?.keepRunningInMenuBar = enabled
      result(nil)
    }

    super.awakeFromNib()
  }
}
