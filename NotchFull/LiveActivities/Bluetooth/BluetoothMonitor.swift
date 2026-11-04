import CoreBluetooth
import Foundation
import IOBluetooth
import Observation
import os

/// Reports Bluetooth devices connecting and disconnecting after launch.
@MainActor
@Observable
final class BluetoothMonitor: NSObject {
    /// Called on connect (then again once battery details arrive) and on disconnect.
    @ObservationIgnored var onEvent: ((BluetoothDevice) -> Void)?
    private(set) var lastError: String?

    /// AirPods publish their battery a moment after connecting.
    private static let batteryRetryDelay: Duration = .seconds(2)
    private static let log = Logger(subsystem: "com.victornovais.NotchFull", category: "bluetooth")

    @ObservationIgnored private var connectNotification: IOBluetoothUserNotification?
    @ObservationIgnored private var connectedAddresses: Set<String> = []
    /// Only used to ask for the Bluetooth permission without blocking; see `init`.
    @ObservationIgnored private var permissionRequester: CBCentralManager?

    override init() {
        super.init()
        // IOBluetooth blocks the calling thread until the user answers the permission prompt, which would hold
        // the whole app at launch. Ask through CoreBluetooth instead (asynchronous) and start once allowed.
        switch CBManager.authorization {
        case .allowedAlways:
            startMonitoring()
        case .notDetermined:
            permissionRequester = CBCentralManager(delegate: self, queue: .main)
        case .denied, .restricted:
            reportPermissionDenied()
        @unknown default:
            reportPermissionDenied()
        }
    }

    private func startMonitoring() {
        guard connectNotification == nil else { return }
        // Devices already connected now are not news; IOBluetooth reports them right after registering.
        connectedAddresses = Set(
            (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? [])
                .filter { $0.isConnected() }
                .compactMap { $0.addressString.map(BluetoothDevice.normalizedAddress) }
        )
        connectNotification = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(deviceConnected(_:device:))
        )
        lastError = nil
        Self.log.info("Started: connectedAtLaunch=\(self.connectedAddresses.count, privacy: .public) registered=\(self.connectNotification != nil, privacy: .public)")
    }

    private func reportPermissionDenied() {
        lastError = "Bluetooth access is off. Allow NotchFull in System Settings → Privacy & Security → Bluetooth."
        Self.log.error("Bluetooth permission denied or restricted")
    }

    // IOBluetooth delivers connect and disconnect notifications on its own CoreBluetooth queue, not on the main
    // thread. These entry points stay nonisolated, extract plain values and hop to the main queue in arrival
    // order before touching any state.
    @objc nonisolated private func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        device.register(forDisconnectNotification: self, selector: #selector(deviceDisconnected(_:device:)))
        guard let rawAddress = device.addressString else { return }
        let address = BluetoothDevice.normalizedAddress(rawAddress)
        let name = device.name ?? "Bluetooth device"
        DispatchQueue.main.async {
            MainActor.assumeIsolated { self.handleConnected(address: address, name: name) }
        }
    }

    @objc nonisolated private func deviceDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        notification.unregister()
        guard let rawAddress = device.addressString else { return }
        let address = BluetoothDevice.normalizedAddress(rawAddress)
        let name = device.name ?? "Bluetooth device"
        DispatchQueue.main.async {
            MainActor.assumeIsolated { self.handleDisconnected(address: address, name: name) }
        }
    }

    private func handleConnected(address: String, name: String) {
        guard connectedAddresses.insert(address).inserted else {
            Self.log.debug("Connect ignored, already connected at launch: \(address, privacy: .public)")
            return
        }
        Self.log.info("Connected: \(name, privacy: .public) \(address, privacy: .public)")
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

    private func handleDisconnected(address: String, name: String) {
        connectedAddresses.remove(address)
        Self.log.info("Disconnected: \(address, privacy: .public)")
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

extension BluetoothMonitor: CBCentralManagerDelegate {
    // Called on the main queue (see `CBCentralManager(delegate:queue:)`) once the user answers the prompt.
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        MainActor.assumeIsolated {
            switch CBManager.authorization {
            case .allowedAlways:
                permissionRequester = nil
                startMonitoring()
            case .denied, .restricted:
                permissionRequester = nil
                reportPermissionDenied()
            case .notDetermined:
                break
            @unknown default:
                reportPermissionDenied()
            }
        }
    }
}
