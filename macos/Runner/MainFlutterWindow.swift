import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    // Setting contentViewController resizes the window to the view, so keep
    // the nib's frame and re-apply it.
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    // The Flutter view can shrink the window back to its default 800×600 as
    // it lays out; re-apply once the run loop has settled.
    DispatchQueue.main.async {
      self.setContentSize(NSSize(width: 1280, height: 820))
      self.center()
    }
    self.minSize = NSSize(width: 800, height: 560)
    self.title = "Yume"

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
