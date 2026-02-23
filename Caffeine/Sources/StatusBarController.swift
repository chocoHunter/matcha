import AppKit

class StatusBarController {
    private var statusItem: NSStatusItem
    private var menu: NSMenu

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu = NSMenu()
        statusItem.menu = menu
        setupMenu()
    }

    private func setupMenu() {
        // Will be implemented in Task 6
    }
}
