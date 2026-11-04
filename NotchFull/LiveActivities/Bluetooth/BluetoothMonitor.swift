import Foundation
import IOBluetooth
import Observation

/// Reports Bluetooth devices connecting and disconnecting after launch.
@MainActor
@Observable
final class BluetoothMonitor: NSObject {
    /// Called on connect (then again once battery details arrive) and on disconnect.
    @ObservationIgnored var onEvent: ((BluetoothDevice) -> Void)?
    private(set) var lastError: String?

    /// AirPods publish their battery a moment after connecting.
    private static let batteryRetryDelay: Duration = .seconds(2)

    @ObservationIgnored private var connectNotification: IOBluetoothUserNotification?
    @ObservationIgnored private var connectedAddresses: Set<String> = []

    override init() {
        super.init()
        // Devices already connected at launch are not news; IOBluetooth reports them right after registering.
        connectedAddresses = Set(
            (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? [])
                .filter { $0.isConnected() }
                .compactMap { $0.addressString.map(BluetoothDevice.normalizedAddress) }
        )
        connectNotification = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(deviceConnected(_:device:))
        )
    }

    @objc private func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        device.register(forDisconnectNotification: self, selector: #selector(deviceDisconnected(_:device:)))
        guard let rawAddress = device.addressString else { return }
        let address = BluetoothDevice.normalizedAddress(rawAddress)
        guard connectedAddresses.insert(address).inserted else { return }

        let name = device.name ?? "Bluetooth device"
        let connected = BluetoothDevice(
            address: address,
            name: name,
            kind: .classify(name: name, minorType: nil, vendorID: nil, productID: nil),
            isConnected: true,
            batteryLevel: nil
        )
        onEvent?(connected)
        loadDetails(for: connected)
    }

    @objc private func deviceDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        notification.unregister()
        guard let rawAddress = device.addressString else { return }
        let address = BluetoothDevice.normalizedAddress(rawAddress)
        connectedAddresses.remove(address)

        let name = device.name ?? "Bluetooth device"
        onEvent?(BluetoothDevice(
            address: address,
            name: name,
            kind: .classify(name: name, minorType: nil, vendorID: nil, productID: nil),
            isConnected: false,
            batteryLevel: nil
        ))
    }

    private func loadDetails(for device: BluetoothDevice) {
        Task {
            do {
                var details = try await SystemProfilerBluetooth.details(for: device.address)
                if details?.batteryLevel == nil {
                    try await Task.sleep(for: Self.batteryRetryDelay)
                    details = try await SystemProfilerBluetooth.details(for: device.address)
                }
                guard let details, connectedAddresses.contains(device.address) else { return }

                var updated = device
                updated.kind = .classify(name: device.name, minorType: details.minorType, vendorID: details.vendorID, productID: details.productID)
                updated.batteryLevel = details.batteryLevel
                guard updated != device else { return }
                lastError = nil
                onEvent?(updated)
            } catch {
                lastError = error.localizedDescription
            }
        }
    }
}
