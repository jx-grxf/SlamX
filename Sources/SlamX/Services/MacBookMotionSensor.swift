import Foundation
import IOKit
import IOKit.hid
import SlamXCore

enum MotionSensorError: LocalizedError {
    case deviceNotFound
    case openFailed(IOReturn)

    var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            "No Apple SPU accelerometer was found on this Mac."
        case .openFailed(let code):
            "The accelerometer could not be opened. IOKit returned \(code)."
        }
    }
}

final class MacBookMotionSensor: MotionSensorStreaming {
    private let reportBuffer: UnsafeMutablePointer<UInt8>
    private let reportLength: Int
    private var device: IOHIDDevice?
    private var sampleHandler: SampleHandler?

    init(reportLength: Int = 4096) {
        self.reportLength = reportLength
        self.reportBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: reportLength)
        self.reportBuffer.initialize(repeating: 0, count: reportLength)
    }

    deinit {
        stop()
        reportBuffer.deallocate()
    }

    func start(sampleHandler: @escaping SampleHandler) throws {
        stop()
        Self.wakeSPUDrivers()

        guard let device = Self.createAccelerometerDevice() else {
            throw MotionSensorError.deviceNotFound
        }

        self.device = device
        self.sampleHandler = sampleHandler

        let openResult = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openResult == kIOReturnSuccess else {
            stop()
            throw MotionSensorError.openFailed(openResult)
        }

        IOHIDDeviceRegisterInputReportCallback(
            device,
            reportBuffer,
            reportLength,
            Self.inputReportCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )

        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    }

    func stop() {
        guard let device else {
            return
        }

        IOHIDDeviceCancel(device)
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))

        self.device = nil
        self.sampleHandler = nil
    }

    static func isAccelerometerAvailable() -> Bool {
        wakeSPUDrivers()

        guard let device = createAccelerometerDevice() else {
            return false
        }

        let openResult = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openResult == kIOReturnSuccess else {
            return false
        }

        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        return true
    }

    private static func wakeSPUDrivers(reportIntervalMicroseconds: Int32 = 1000) {
        let matchingDictionary = IOServiceMatching("AppleSPUHIDDriver")
        var iterator: io_iterator_t = 0

        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchingDictionary, &iterator) == kIOReturnSuccess else {
            return
        }

        defer {
            IOObjectRelease(iterator)
        }

        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else {
                break
            }
            defer {
                IOObjectRelease(service)
            }

            setRegistryInt(service, key: "SensorPropertyReportingState", value: 1)
            setRegistryInt(service, key: "SensorPropertyPowerState", value: 1)
            setRegistryInt(service, key: "ReportInterval", value: reportIntervalMicroseconds)
        }
    }

    private func handleReport(_ report: [UInt8]) {
        guard let sample = MotionReportParser.sample(from: report) else {
            return
        }

        sampleHandler?(sample)
    }

    private static let inputReportCallback: IOHIDReportCallback = { context, result, _, _, _, report, reportLength in
        guard result == kIOReturnSuccess, let context else {
            return
        }

        let sensor = Unmanaged<MacBookMotionSensor>.fromOpaque(context).takeUnretainedValue()
        let buffer = UnsafeBufferPointer(start: report, count: reportLength)
        sensor.handleReport(Array(buffer))
    }

    private static func createAccelerometerDevice() -> IOHIDDevice? {
        let matchingDictionary = IOServiceMatching("AppleSPUHIDDevice")
        var iterator: io_iterator_t = 0

        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchingDictionary, &iterator) == kIOReturnSuccess else {
            return nil
        }

        defer {
            IOObjectRelease(iterator)
        }

        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else {
                break
            }
            defer {
                IOObjectRelease(service)
            }

            let usagePage = registryInt(service, key: "PrimaryUsagePage")
            let usage = registryInt(service, key: "PrimaryUsage")

            guard usagePage == 0xFF00, usage == 0x03 else {
                continue
            }

            return IOHIDDeviceCreate(kCFAllocatorDefault, service)
        }

        return nil
    }

    private static func registryInt(_ service: io_service_t, key: String) -> Int? {
        guard let value = IORegistryEntryCreateCFProperty(
            service,
            key as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? NSNumber else {
            return nil
        }

        return value.intValue
    }

    private static func setRegistryInt(_ service: io_service_t, key: String, value: Int32) {
        var mutableValue = value
        guard let number = CFNumberCreate(kCFAllocatorDefault, .sInt32Type, &mutableValue) else {
            return
        }

        IORegistryEntrySetCFProperty(service, key as CFString, number)
    }
}
