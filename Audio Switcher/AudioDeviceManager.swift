import CoreAudio
import Foundation

struct AudioDevice {
    let id: AudioObjectID
    let name: String
}

final class AudioDeviceManager {
    var onDevicesChanged: (() -> Void)?

    private let listenerQueue = DispatchQueue.main
    private var listenerBlock: AudioObjectPropertyListenerBlock?
    private var muteListenerDeviceID: AudioObjectID?

    init() {
        startListening()
    }

    deinit {
        stopListening()
    }

    func inputDevices() -> [AudioDevice] {
        allDevices().filter { hasInputChannels(deviceID: $0.id) }
    }

    func outputDevices() -> [AudioDevice] {
        allDevices().filter { hasOutputChannels(deviceID: $0.id) }
    }

    func defaultInputDeviceID() -> AudioObjectID? {
        readObjectIDProperty(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDefaultInputDevice,
            scope: kAudioObjectPropertyScopeGlobal,
            element: kAudioObjectPropertyElementMain
        )
    }

    func defaultOutputDeviceID() -> AudioObjectID? {
        readObjectIDProperty(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDefaultOutputDevice,
            scope: kAudioObjectPropertyScopeGlobal,
            element: kAudioObjectPropertyElementMain
        )
    }

    func setDefaultInputDevice(_ deviceID: AudioObjectID) {
        setDefaultDevice(deviceID, selector: kAudioHardwarePropertyDefaultInputDevice)
    }

    func setDefaultOutputDevice(_ deviceID: AudioObjectID) {
        setDefaultDevice(deviceID, selector: kAudioHardwarePropertyDefaultOutputDevice)
    }

    func isInputMuted(deviceID: AudioObjectID) -> Bool {
        let muted = readUInt32Property(
            objectID: deviceID,
            selector: kAudioDevicePropertyMute,
            scope: kAudioObjectPropertyScopeInput,
            element: kAudioObjectPropertyElementMain
        )

        return muted == 1
    }

    func unmuteInput(deviceID: AudioObjectID) {
        var muted: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectSetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<UInt32>.size),
            &muted
        )

        if status != noErr {
            NSLog("Failed to unmute audio input device %u, status: %d", deviceID, status)
        }
    }

    private func allDevices() -> [AudioDevice] {
        let deviceIDs = readObjectIDArrayProperty(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDevices,
            scope: kAudioObjectPropertyScopeGlobal,
            element: kAudioObjectPropertyElementMain
        )

        return deviceIDs.compactMap { id in
            guard isAlive(deviceID: id), let name = deviceName(for: id), !name.isEmpty else {
                return nil
            }

            return AudioDevice(id: id, name: name)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func deviceName(for deviceID: AudioObjectID) -> String? {
        guard let name = readCFStringProperty(
            objectID: deviceID,
            selector: kAudioObjectPropertyName,
            scope: kAudioObjectPropertyScopeGlobal,
            element: kAudioObjectPropertyElementMain
        ) else {
            return nil
        }

        return name as String
    }

    private func isAlive(deviceID: AudioObjectID) -> Bool {
        let alive = readUInt32Property(
            objectID: deviceID,
            selector: kAudioDevicePropertyDeviceIsAlive,
            scope: kAudioObjectPropertyScopeGlobal,
            element: kAudioObjectPropertyElementMain
        )

        return alive == 1
    }

    private func hasInputChannels(deviceID: AudioObjectID) -> Bool {
        hasChannels(deviceID: deviceID, scope: kAudioObjectPropertyScopeInput)
    }

    private func hasOutputChannels(deviceID: AudioObjectID) -> Bool {
        hasChannels(deviceID: deviceID, scope: kAudioObjectPropertyScopeOutput)
    }

    private func hasChannels(deviceID: AudioObjectID, scope: AudioObjectPropertyScope) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize)
        guard status == noErr, dataSize > 0 else {
            return false
        }

        let bufferListPointer = UnsafeMutableRawPointer.allocate(
            byteCount: Int(dataSize),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { bufferListPointer.deallocate() }

        var mutableDataSize = dataSize
        let getStatus = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &mutableDataSize, bufferListPointer)
        guard getStatus == noErr else {
            return false
        }

        let bufferList = bufferListPointer.assumingMemoryBound(to: AudioBufferList.self)
        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        return buffers.contains { $0.mNumberChannels > 0 }
    }

    private func setDefaultDevice(_ deviceID: AudioObjectID, selector: AudioObjectPropertySelector) {
        var mutableDeviceID = deviceID
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            UInt32(MemoryLayout<AudioObjectID>.size),
            &mutableDeviceID
        )

        if status != noErr {
            NSLog("Failed to set default audio device (selector: %u), status: %d", selector, status)
        }
    }

    private func startListening() {
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.updateInputMuteListener()
            self?.onDevicesChanged?()
        }

        listenerBlock = block

        addListener(selector: kAudioHardwarePropertyDevices, block: block)
        addListener(selector: kAudioHardwarePropertyDefaultInputDevice, block: block)
        addListener(selector: kAudioHardwarePropertyDefaultOutputDevice, block: block)
        updateInputMuteListener()
    }

    private func stopListening() {
        guard let block = listenerBlock else { return }

        removeListener(selector: kAudioHardwarePropertyDevices, block: block)
        removeListener(selector: kAudioHardwarePropertyDefaultInputDevice, block: block)
        removeListener(selector: kAudioHardwarePropertyDefaultOutputDevice, block: block)

        if let deviceID = muteListenerDeviceID {
            removeListener(objectID: deviceID, selector: kAudioDevicePropertyMute, scope: kAudioObjectPropertyScopeInput, block: block)
            muteListenerDeviceID = nil
        }

        listenerBlock = nil
    }

    // The mute state lives on the device rather than the system object, so the listener has to
    // follow whichever device is currently the default input.
    private func updateInputMuteListener() {
        guard let block = listenerBlock else { return }

        let deviceID = defaultInputDeviceID()
        guard deviceID != muteListenerDeviceID else { return }

        if let oldDeviceID = muteListenerDeviceID {
            removeListener(objectID: oldDeviceID, selector: kAudioDevicePropertyMute, scope: kAudioObjectPropertyScopeInput, block: block)
            muteListenerDeviceID = nil
        }

        if let deviceID, hasProperty(objectID: deviceID, selector: kAudioDevicePropertyMute, scope: kAudioObjectPropertyScopeInput) {
            addListener(objectID: deviceID, selector: kAudioDevicePropertyMute, scope: kAudioObjectPropertyScopeInput, block: block)
            muteListenerDeviceID = deviceID
        }
    }

    private func hasProperty(objectID: AudioObjectID, selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )

        return AudioObjectHasProperty(objectID, &address)
    }

    private func addListener(
        objectID: AudioObjectID = AudioObjectID(kAudioObjectSystemObject),
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        block: @escaping AudioObjectPropertyListenerBlock
    ) {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectAddPropertyListenerBlock(
            objectID,
            &address,
            listenerQueue,
            block
        )

        if status != noErr {
            NSLog("Failed to add CoreAudio listener for selector %u, status: %d", selector, status)
        }
    }

    private func removeListener(
        objectID: AudioObjectID = AudioObjectID(kAudioObjectSystemObject),
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        block: @escaping AudioObjectPropertyListenerBlock
    ) {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectRemovePropertyListenerBlock(
            objectID,
            &address,
            listenerQueue,
            block
        )

        if status != noErr {
            NSLog("Failed to remove CoreAudio listener for selector %u, status: %d", selector, status)
        }
    }

    private func readObjectIDProperty(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement
    ) -> AudioObjectID? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
        var value = AudioObjectID(0)
        var dataSize = UInt32(MemoryLayout<AudioObjectID>.size)

        let status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, &value)
        return status == noErr ? value : nil
    }

    private func readUInt32Property(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement
    ) -> UInt32? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
        var value: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)

        let status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, &value)
        return status == noErr ? value : nil
    }

    private func readCFStringProperty(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement
    ) -> CFString? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
        var value: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)

        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, pointer)
        }

        guard status == noErr else {
            return nil
        }

        return value?.takeUnretainedValue()
    }

    private func readObjectIDArrayProperty(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement
    ) -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)

        var dataSize: UInt32 = 0
        let sizeStatus = AudioObjectGetPropertyDataSize(objectID, &address, 0, nil, &dataSize)
        guard sizeStatus == noErr, dataSize > 0 else {
            return []
        }

        let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var values = Array(repeating: AudioObjectID(0), count: count)

        let status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, &values)
        guard status == noErr else {
            return []
        }

        return values
    }
}
