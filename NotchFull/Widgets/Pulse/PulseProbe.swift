import Darwin
import Foundation
import IOKit

/// Reads the raw counters behind each metric with public system APIs. The calls block (IORegistry and the
/// volume query in particular), so the sampler runs `capture` off the main actor.
enum PulseProbe {
    /// One read of every requested metric; `nil` means the metric was not requested.
    struct Snapshot: Sendable {
        var cpu: Result<CPUTicks, PulseReadError>?
        var ram: Result<MemoryCounters, PulseReadError>?
        var gpu: Result<Double, PulseReadError>?
        var disk: Result<DiskCapacity, PulseReadError>?
        var network: Result<NetworkCounters, PulseReadError>?
    }

    static func capture(_ metrics: Set<PulseMetric>) -> Snapshot {
        var snapshot = Snapshot()
        if metrics.contains(.cpu) { snapshot.cpu = readCPUTicks() }
        if metrics.contains(.ram) { snapshot.ram = readMemory() }
        if metrics.contains(.gpu) { snapshot.gpu = readGPUUtilization() }
        if metrics.contains(.disk) { snapshot.disk = readDiskCapacity() }
        if metrics.contains(.network) { snapshot.network = readNetworkCounters() }
        return snapshot
    }

    static func readCPUTicks() -> Result<CPUTicks, PulseReadError> {
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }

        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        let status = host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount)
        guard status == KERN_SUCCESS, let info else {
            return .failure(PulseReadError(message: "CPU: host_processor_info failed (\(machErrorDescription(status)))."))
        }
        // The kernel allocates the array in our address space; it must be returned or every sample leaks it.
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride))
        }

        let stride = Int(CPU_STATE_MAX)
        guard Int(infoCount) >= Int(cpuCount) * stride else {
            return .failure(PulseReadError(message: "CPU: the kernel returned fewer load counters than cores."))
        }
        let cores = (0..<Int(cpuCount)).map { index in
            let base = index * stride
            return CPUTicks.Core(
                user: UInt32(bitPattern: info[base + Int(CPU_STATE_USER)]),
                system: UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)]),
                idle: UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)]),
                nice: UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)])
            )
        }
        return .success(CPUTicks(cores: cores))
    }

    static func readMemory() -> Result<MemoryCounters, PulseReadError> {
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }

        var pageSize: vm_size_t = 0
        let pageStatus = host_page_size(host, &pageSize)
        guard pageStatus == KERN_SUCCESS, pageSize > 0 else {
            return .failure(PulseReadError(message: "RAM: host_page_size failed (\(machErrorDescription(pageStatus)))."))
        }

        var statistics = vm_statistics64()
        // HOST_VM_INFO64_COUNT is a C macro Swift cannot import.
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard status == KERN_SUCCESS else {
            return .failure(PulseReadError(message: "RAM: host_statistics64 failed (\(machErrorDescription(status)))."))
        }
        return .success(MemoryCounters(
            activePages: UInt64(statistics.active_count),
            wiredPages: UInt64(statistics.wire_count),
            compressedPages: UInt64(statistics.compressor_page_count),
            pageSize: UInt64(pageSize),
            physicalMemory: ProcessInfo.processInfo.physicalMemory
        ))
    }

    /// Highest utilization among the GPUs. The "PerformanceStatistics" key is not a documented contract, so its
    /// absence is reported as unavailable instead of 0%.
    static func readGPUUtilization() -> Result<Double, PulseReadError> {
        var iterator: io_iterator_t = 0
        let status = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator)
        guard status == KERN_SUCCESS else {
            return .failure(PulseReadError(message: "GPU: the graphics driver could not be queried (\(machErrorDescription(status)))."))
        }
        defer { IOObjectRelease(iterator) }

        var utilization: Double?
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            guard
                let property = IORegistryEntryCreateCFProperty(service, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)?
                    .takeRetainedValue(),
                let statistics = property as? [String: Any],
                let percent = (statistics["Device Utilization %"] as? NSNumber)?.doubleValue
            else { continue }
            utilization = max(utilization ?? 0, percent)
        }

        guard let utilization else {
            return .failure(PulseReadError(message: "GPU: this Mac's graphics driver does not report utilization."))
        }
        return .success(utilization)
    }

    static func readDiskCapacity() -> Result<DiskCapacity, PulseReadError> {
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        do {
            let values = try URL(filePath: "/").resourceValues(forKeys: keys)
            guard let total = values.volumeTotalCapacity, let available = values.volumeAvailableCapacityForImportantUsage else {
                return .failure(PulseReadError(message: "Disk: the startup volume did not report its capacity."))
            }
            return .success(DiskCapacity(totalBytes: Int64(total), availableBytes: available))
        } catch {
            return .failure(PulseReadError(message: "Disk: \(error.localizedDescription)"))
        }
    }

    static func readNetworkCounters() -> Result<NetworkCounters, PulseReadError> {
        var addresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses) == 0, let first = addresses else {
            return .failure(PulseReadError(message: "Network: getifaddrs failed (\(String(cString: strerror(errno))))."))
        }
        defer { freeifaddrs(addresses) }
        let uptime = ProcessInfo.processInfo.systemUptime

        var interfaces: [String: NetworkCounters.Bytes] = [:]
        for entry in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = entry.pointee
            let flags = Int32(interface.ifa_flags)
            // Only link-layer entries carry `if_data`; `en*` are Wi-Fi and Ethernet, which leaves out loopback and VPN tunnels.
            guard
                let address = interface.ifa_addr, address.pointee.sa_family == UInt8(AF_LINK),
                flags & IFF_UP != 0, flags & IFF_RUNNING != 0,
                let data = interface.ifa_data
            else { continue }
            let name = String(cString: interface.ifa_name)
            guard name.hasPrefix("en") else { continue }
            let counters = data.assumingMemoryBound(to: if_data.self).pointee
            interfaces[name] = NetworkCounters.Bytes(received: counters.ifi_ibytes, sent: counters.ifi_obytes)
        }
        return .success(NetworkCounters(interfaces: interfaces, uptime: uptime))
    }

    private static func machErrorDescription(_ status: kern_return_t) -> String {
        guard let message = mach_error_string(status) else { return "error \(status)" }
        return String(cString: message)
    }
}
