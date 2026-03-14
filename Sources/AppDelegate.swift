import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Best effort cleanup without triggering extra privilege prompt during termination.
        MatchaManager.shared.stop(restoreBatteryOverride: false)
    }
}
