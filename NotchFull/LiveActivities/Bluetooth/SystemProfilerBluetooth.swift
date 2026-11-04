import Foundation

enum SystemProfilerError: LocalizedError {
    case failed(status: Int32)
    case unexpectedFormat

    var errorDescription: String? {
        switch self {
        case let .failed(status): "system_profiler exited with status \(status)."
        case .unexpectedFormat: "system_profiler returned Bluetooth data in an unexpected format."
        }
    }
}

/// Battery and model details that IOBluetooth does not expose publicly, read from `system_profiler`.
enum SystemProfilerBluetooth {
    struct Details: Sendable {
        let batteryLevel: Double?
        let minorType: String?
        let vendorID: Int?
        let productID: Int?
    }

    /// Details for the connected device at `address`; `nil` when the device is not listed as connected.
    static func details(for address: String) async throws -> Details? {
        let data = try await run()
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let controllers = root["SPBluetoothDataType"] as? [[String: Any]]
        else { throw SystemProfilerError.unexpectedFormat }

        for controller in controllers {
            guard let connected = controller["device_connected"] as? [[String: [String: Any]]] else { continue }
            for entry in connected {
                for (_, info) in entry {
                    guard let rawAddress = info["device_address"] as? String,
                          BluetoothDevice.normalizedAddress(rawAddress) == address else { continue }
                    return Details(
                        batteryLevel: batteryLevel(in: info),
                        minorType: info["device_minorType"] as? String,
                        vendorID: hexValue(info["device_vendorID"]),
                        productID: hexValue(info["device_productID"])
                    )
                }
            }
        }
        return nil
    }

    // AirPods report each earbud; the lowest one is what runs out first. The case level is ignored.
    private static func batteryLevel(in info: [String: Any]) -> Double? {
        let earbuds = ["device_batteryLevelLeft", "device_batteryLevelRight"].compactMap { percent(info[$0]) }
        if let lowest = earbuds.min() { return lowest }
        return percent(info["device_batteryLevelMain"]) ?? percent(info["device_batteryLevel"])
    }

    private static func percent(_ value: Any?) -> Double? {
        guard let text = value as? String, let number = Double(text.replacingOccurrences(of: "%", with: "")) else { return nil }
        return number / 100
    }

    private static func hexValue(_ value: Any?) -> Int? {
        guard let text = value as? String else { return nil }
        return Int(text.replacingOccurrences(of: "0x", with: ""), radix: 16)
    }

    private static func run() async throws -> Data {
        try await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
            process.arguments = ["SPBluetoothDataType", "-json"]
            let output = Pipe()
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice

            try process.run()
            // Read before waiting: a full pipe would otherwise block the child forever.
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                throw SystemProfilerError.failed(status: process.terminationStatus)
            }
            return data
        }.value
    }
}
