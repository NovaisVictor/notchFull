import Foundation

/// A Bluetooth device as shown in the connect/disconnect activity.
struct BluetoothDevice: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case airpods
        case airpodsPro
        case airpodsMax
        case headphones
        case keyboard
        case mouse
        case speaker
        case other

        var systemImage: String {
            switch self {
            case .airpods: "airpods"
            case .airpodsPro: "airpods.pro"
            case .airpodsMax: "airpods.max"
            case .headphones: "headphones"
            case .keyboard: "keyboard"
            case .mouse: "computermouse"
            case .speaker: "hifispeaker"
            case .other: "dot.radiowaves.left.and.right"
            }
        }

        // Apple's product IDs; custom device names ("AirPods de Victor") do not say which model it is.
        private static let airpodsProIDs: Set<Int> = [0x200E, 0x2014, 0x2024, 0x2027]
        private static let airpodsMaxIDs: Set<Int> = [0x200A, 0x201F]
        private static let appleVendorID = 0x004C

        static func classify(name: String, minorType: String?, vendorID: Int?, productID: Int?) -> Kind {
            let lowercasedName = name.lowercased()
            if vendorID == appleVendorID, let productID {
                if airpodsProIDs.contains(productID) { return .airpodsPro }
                if airpodsMaxIDs.contains(productID) { return .airpodsMax }
            }
            if lowercasedName.contains("airpods max") { return .airpodsMax }
            if lowercasedName.contains("airpods pro") { return .airpodsPro }
            if lowercasedName.contains("airpods") { return .airpods }

            switch minorType?.lowercased() {
            case "headphones", "headset": return .headphones
            case "keyboard": return .keyboard
            case "mouse", "trackpad": return .mouse
            case "speaker", "loudspeaker": return .speaker
            default: return .other
            }
        }
    }

    /// Normalized as uppercase, colon-separated (AA:BB:CC:DD:EE:FF).
    let address: String
    let name: String
    var kind: Kind
    let isConnected: Bool
    /// Lowest earbud level for AirPods, otherwise the device level; `nil` when the device does not report one.
    var batteryLevel: Double?

    static func normalizedAddress(_ raw: String) -> String {
        raw.uppercased().replacingOccurrences(of: "-", with: ":")
    }
}
