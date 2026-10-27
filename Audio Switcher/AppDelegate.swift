import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let audioDeviceManager = AudioDeviceManager()
    private let launchAtLoginManager = LaunchAtLoginManager()

    private var statusItem: NSStatusItem!
    private let menu = NSMenu()

    private let warningDot: NSView = {
        let dot = NSView()
        dot.wantsLayer = true
        dot.layer?.backgroundColor = NSColor.systemRed.cgColor
        dot.layer?.cornerRadius = 3
        dot.isHidden = true
        dot.translatesAutoresizingMaskIntoConstraints = false
        return dot
    }()

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

        if let button = statusItem.button {
            button.addSubview(warningDot)

            // Pin the dot to the top-right corner of the speaker icon, which is centered in the button.
            NSLayoutConstraint.activate([
                warningDot.widthAnchor.constraint(equalToConstant: 6),
                warningDot.heightAnchor.constraint(equalToConstant: 6),
                warningDot.centerXAnchor.constraint(equalTo: button.centerXAnchor, constant: 8),
                warningDot.centerYAnchor.constraint(equalTo: button.centerYAnchor, constant: -5),
            ])
        }
    }

    private func setupObservers() {
        audioDeviceManager.onDevicesChanged = { [weak self] in
            self?.rebuildMenu()
        }
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let warningItems = blackHoleWarningItems()
        warningDot.isHidden = warningItems.isEmpty

        if !warningItems.isEmpty {
            for item in warningItems {
                menu.addItem(item)
            }
            menu.addItem(.separator())
        }

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

    // BlackHole sometimes comes back muted or with a lowered input level, usually after a reboot.
    private func blackHoleWarningItems() -> [NSMenuItem] {
        guard
            let defaultInputID = audioDeviceManager.defaultInputDeviceID(),
            let device = audioDeviceManager.inputDevices().first(where: { $0.id == defaultInputID }),
            device.name.localizedCaseInsensitiveContains("BlackHole")
        else {
            return []
        }

        var items: [NSMenuItem] = []

        if audioDeviceManager.isInputMuted(deviceID: device.id) {
            items.append(deviceActionItem(title: "Unmute \(device.name)", action: #selector(unmuteInput(_:)), device: device))
        }

        if let volume = audioDeviceManager.inputVolume(deviceID: device.id) {
            let percent = Int((volume * 100).rounded())
            if percent < 100 {
                items.append(deviceActionItem(
                    title: "Set \(device.name) Input Level to 100% (now \(percent)%)",
                    action: #selector(setFullInputVolume(_:)),
                    device: device
                ))
            }
        }

        return items
    }

    private func deviceActionItem(title: String, action: Selector, device: AudioDevice) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.representedObject = NSNumber(value: device.id)
        return item
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

    @objc private func unmuteInput(_ sender: NSMenuItem) {
        guard let number = sender.representedObject as? NSNumber else { return }
        audioDeviceManager.unmuteInput(deviceID: number.uint32Value)
        rebuildMenu()
    }

    @objc private func setFullInputVolume(_ sender: NSMenuItem) {
        guard let number = sender.representedObject as? NSNumber else { return }
        audioDeviceManager.setInputVolume(1, deviceID: number.uint32Value)
        rebuildMenu()
    }

    @objc private func toggleLaunchAtLogin() {
        launchAtLoginManager.setEnabled(!launchAtLoginManager.isEnabled)
        rebuildMenu()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
