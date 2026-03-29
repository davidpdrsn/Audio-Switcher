import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let audioDeviceManager = AudioDeviceManager()
    private let launchAtLoginManager = LaunchAtLoginManager()

    private var statusItem: NSStatusItem!
    private let menu = NSMenu()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupObservers()
        rebuildMenu()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: "Audio Switcher")
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.toolTip = "Audio Switcher"
        statusItem.menu = menu
    }

    private func setupObservers() {
        audioDeviceManager.onDevicesChanged = { [weak self] in
            self?.rebuildMenu()
        }
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        addSectionHeader("Inputs")
        addInputItems()

        menu.addItem(.separator())

        addSectionHeader("Outputs")
        addOutputItems()

        menu.addItem(.separator())

        let launchAtLoginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginItem.target = self
        launchAtLoginItem.state = launchAtLoginManager.isEnabled ? .on : .off
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Audio Switcher", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func addSectionHeader(_ title: String) {
        let header = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
    }

    private func addInputItems() {
        let inputs = audioDeviceManager.inputDevices()
        let defaultInputID = audioDeviceManager.defaultInputDeviceID()

        if inputs.isEmpty {
            let emptyItem = NSMenuItem(title: "(No input devices)", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
            return
        }

        for device in inputs {
            let item = NSMenuItem(title: device.name, action: #selector(selectInput(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = NSNumber(value: device.id)
            item.state = (device.id == defaultInputID) ? .on : .off
            menu.addItem(item)
        }
    }

    private func addOutputItems() {
        let outputs = audioDeviceManager.outputDevices()
        let defaultOutputID = audioDeviceManager.defaultOutputDeviceID()

        if outputs.isEmpty {
            let emptyItem = NSMenuItem(title: "(No output devices)", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
            return
        }

        for device in outputs {
            let item = NSMenuItem(title: device.name, action: #selector(selectOutput(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = NSNumber(value: device.id)
            item.state = (device.id == defaultOutputID) ? .on : .off
            menu.addItem(item)
        }
    }

    @objc private func selectInput(_ sender: NSMenuItem) {
        guard let number = sender.representedObject as? NSNumber else { return }
        audioDeviceManager.setDefaultInputDevice(number.uint32Value)
    }

    @objc private func selectOutput(_ sender: NSMenuItem) {
        guard let number = sender.representedObject as? NSNumber else { return }
        audioDeviceManager.setDefaultOutputDevice(number.uint32Value)
    }

    @objc private func toggleLaunchAtLogin() {
        launchAtLoginManager.setEnabled(!launchAtLoginManager.isEnabled)
        rebuildMenu()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
