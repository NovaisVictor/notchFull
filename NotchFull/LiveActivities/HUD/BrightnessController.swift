import CoreGraphics
import Darwin
import Foundation
import os

enum BrightnessControlError: LocalizedError {
    case displayServices(operation: String, status: Int32)
    case coreGraphics(operation: String, error: CGError)

    var errorDescription: String? {
        switch self {
        case let .displayServices(operation, status):
            "Could not \(operation) (DisplayServices error \(status))."
        case let .coreGraphics(operation, error):
            "Could not \(operation) (CGError \(error.rawValue))."
        }
    }
}

/// Reads and changes the built-in display's brightness.
///
/// This is the one place NotchFull uses a private Apple API: `DisplayServicesGetBrightness` and
/// `DisplayServicesSetBrightness` from the private DisplayServices framework. macOS has no public API that changes the
/// built-in panel's brightness on Apple Silicon (the IOKit display parameters Intel Macs used are gone), and replacing
/// the brightness HUD means NotchFull must apply the change itself after consuming the key.
///
/// The framework is opened with `dlopen` on first use instead of being linked, so a macOS release that removes or
/// changes it cannot keep the app from launching. Fallback: when the framework or a symbol is missing, a call returns
/// an error, or no built-in display is on, the brightness keys are not consumed, macOS handles them with its own HUD,
/// and the settings page shows why.
@MainActor
final class BrightnessController {
    enum Outcome {
        case applied(HUDState)
        /// Brightness cannot be changed here, so the key must go to macOS untouched.
        case unsupported(reason: String)
    }

    private typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private struct DisplayServices {
        let getBrightness: GetBrightness
        let setBrightness: SetBrightness
    }

    private struct Unavailable: Error {
        let reason: String
    }

    private static let frameworkPath = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
    private static let log = Logger(subsystem: "com.victornovais.NotchFull", category: "brightness")

    /// Loaded only when brightness is first needed, so the private framework stays out of the process for users who
    /// never turn the option on or open its settings.
    private lazy var displayServices: Result<DisplayServices, Unavailable> = Self.loadDisplayServices()

    /// Why the brightness keys can never be handled on this Mac, or `nil` when DisplayServices loaded.
    var unavailableReason: String? {
        switch displayServices {
        case .success: nil
        case let .failure(unavailable): unavailable.reason
        }
    }

    /// Moves the brightness by one step of `1 / steps`, snapping to that grid like the system does.
    func step(up: Bool, steps: Int) throws -> Outcome {
        let api: DisplayServices
        switch displayServices {
        case let .success(loaded): api = loaded
        case let .failure(unavailable): return .unsupported(reason: unavailable.reason)
        }
        guard let display = try builtInDisplay() else {
            return .unsupported(reason: "No built-in display is on (the lid may be closed), so the brightness keys go to macOS.")
        }

        var current: Float = 0
        try check("read the display brightness", api.getBrightness(display, &current))
        let grid = Double(steps)
        let index = (Double(current) * grid).rounded() + (up ? 1 : -1)
        let level = (index / grid).clamped(to: 0...1)
        try check("change the display brightness", api.setBrightness(display, Float(level)))
        return .applied(.brightness(level: level))
    }

    // The handle is never closed: the functions stay in use for the app's lifetime.
    private static func loadDisplayServices() -> Result<DisplayServices, Unavailable> {
        guard let handle = dlopen(frameworkPath, RTLD_LAZY) else {
            let detail = dlerror().map { String(cString: $0) } ?? "no error detail"
            log.error("dlopen DisplayServices failed: \(detail, privacy: .public)")
            return .failure(Unavailable(reason: "This version of macOS does not provide DisplayServices (\(detail)), so the brightness keys go to macOS."))
        }
        guard let getSymbol = dlsym(handle, "DisplayServicesGetBrightness"),
              let setSymbol = dlsym(handle, "DisplayServicesSetBrightness") else {
            let detail = dlerror().map { String(cString: $0) } ?? "no error detail"
            log.error("dlsym DisplayServices brightness failed: \(detail, privacy: .public)")
            return .failure(Unavailable(reason: "DisplayServices on this version of macOS has no brightness functions (\(detail)), so the brightness keys go to macOS."))
        }
        log.info("DisplayServices loaded")
        return .success(DisplayServices(
            getBrightness: unsafeBitCast(getSymbol, to: GetBrightness.self),
            setBrightness: unsafeBitCast(setSymbol, to: SetBrightness.self)
        ))
    }

    /// The Mac's own panel, looked up on every press because it comes and goes with the lid. External displays are
    /// ignored: their brightness goes through DDC, which is out of scope.
    private func builtInDisplay() throws -> CGDirectDisplayID? {
        var count: UInt32 = 0
        try check("list the displays", CGGetOnlineDisplayList(0, nil, &count))
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        try check("list the displays", CGGetOnlineDisplayList(count, &displays, &count))
        // The online list also holds sleeping displays; a sleeping panel shows no change, so its keys stay with macOS.
        return displays.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 && CGDisplayIsAsleep($0) == 0 }
    }

    private func check(_ operation: String, _ status: Int32) throws {
        guard status == 0 else {
            throw BrightnessControlError.displayServices(operation: operation, status: status)
        }
    }

    private func check(_ operation: String, _ error: CGError) throws {
        guard error == .success else {
            throw BrightnessControlError.coreGraphics(operation: operation, error: error)
        }
    }
}
