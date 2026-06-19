import AppKit
import Carbon
import InputMethodKit
import SwiftyBeaver

final class KhiinIMApplication: NSApplication {
    private let appDelegate = AppDelegate()

    override init() {
        super.init()
        self.delegate = appDelegate
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        // No need for implementation
        fatalError("init(coder:) has not been implemented")
    }
}

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.setup()

        let name =
            Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String
        let identifier = Bundle.main.bundleIdentifier
        let _ = IMKServer(name: name, bundleIdentifier: identifier)

        // Register this bundle as an input source so a freshly installed copy
        // shows up in the input source list without a log out / log in. The
        // installer copies the bundle into ~/Library/Input Methods but never
        // registers it with the Text Input system; launching once self-registers
        // here. TISRegisterInputSource is idempotent.
        let status = TISRegisterInputSource(Bundle.main.bundleURL as CFURL)
        log.debug("TISRegisterInputSource status: \(status)")

        log.debug("IMKServer initialized")
    }

    func applicationWillTerminate(_ notification: Notification) {
        // empty
    }
}
