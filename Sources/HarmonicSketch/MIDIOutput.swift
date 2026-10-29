import CoreMIDI
import Foundation

@MainActor final class MIDIOutput {
    private var client: MIDIClientRef = 0
    private var port: MIDIPortRef = 0
    private var endpoints: [MIDIEndpointRef] = []
    private var identifiers: [Int32] = []
    private var selectedIdentifier: Int32?
    private(set) var destinations: [String] = []
    private var currentIndex: Int?
    var onError: ((String) -> Void)?
    var onDestinationChanged: (() -> Void)?
    private(set) var lastError: String?
    var destinationIndex: Int? {
        get { currentIndex }
        set {
            let old = selectedIdentifier
            currentIndex = newValue; selectedIdentifier = newValue.flatMap { identifiers.indices.contains($0) ? identifiers[$0] : nil }
            if old != selectedIdentifier { onDestinationChanged?() }
        }
    }
    init() {
        let clientStatus = MIDIClientCreate("Harmonic Sketch" as CFString, nil, nil, &client)
        if clientStatus != noErr { report("Create MIDI client", status: clientStatus); return }
        let portStatus = MIDIOutputPortCreate(client, "Composer output" as CFString, &port)
        if portStatus != noErr { report("Create MIDI output", status: portStatus); return }
        refresh()
    }
    deinit { if port != 0 { MIDIPortDispose(port) }; if client != 0 { MIDIClientDispose(client) } }
    func refresh() {
        endpoints = (0..<MIDIGetNumberOfDestinations()).map(MIDIGetDestination)
        identifiers = endpoints.map { endpoint in var value: Int32 = 0; let status = MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &value); if status != noErr { report("Read MIDI identifier", status: status) }; return value }
        destinations = endpoints.map { endpoint in
            var name: Unmanaged<CFString>?
            if MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name) == noErr, let name { return name.takeRetainedValue() as String }
            return "MIDI destination"
        }
        let oldIndex = currentIndex
        currentIndex = selectedIdentifier.flatMap { identifiers.firstIndex(of: $0) }
        if oldIndex != currentIndex { onDestinationChanged?() }
    }
    func noteOn(pitch: Int, velocity: Int, channel: Int) { send([0x90 | UInt8(clamping: channel & 15), UInt8(clamping: pitch), UInt8(clamping: velocity)]) }
    func noteOff(pitch: Int, channel: Int) { send([0x80 | UInt8(clamping: channel & 15), UInt8(clamping: pitch), 0]) }
    func programChange(program: Int, channel: Int) { send([0xC0 | UInt8(clamping: channel & 15), UInt8(clamping: program)]) }
    func setVolume(_ volume: Double, channel: Int) { send([0xB0 | UInt8(clamping: channel & 15), 7, UInt8(clamping: Int(min(1, max(0, volume)) * 127))]) }
    func setPan(_ pan: Double, channel: Int) { send([0xB0 | UInt8(clamping: channel & 15), 10, UInt8(clamping: Int(((min(1, max(-1, pan)) + 1) * 63.5).rounded()))]) }
    func silence() { for channel in 0..<16 { send([0xB0 | UInt8(channel), 123, 0]) } }
    private func send(_ bytes: [UInt8]) {
        guard let destinationIndex, endpoints.indices.contains(destinationIndex), port != 0 else { return }
        var list = MIDIPacketList()
        bytes.withUnsafeBufferPointer { buffer in
            let packet = MIDIPacketListInit(&list)
            guard let base = buffer.baseAddress else { return }
            _ = MIDIPacketListAdd(&list, MemoryLayout<MIDIPacketList>.size, packet, 0, bytes.count, base)
        }
        let status = MIDISend(port, endpoints[destinationIndex], &list)
        if status != noErr { report("Send MIDI", status: status) }
    }
    private func report(_ operation: String, status: OSStatus) { let message = "\(operation) failed (CoreMIDI \(status))."; if lastError != message { lastError = message; onError?(message) } }
}
