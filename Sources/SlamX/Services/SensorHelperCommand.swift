import Foundation
import SlamXCore

enum SensorHelperCommand {
    static func run(arguments: [String]) {
        guard let pipePath = value(after: "--pipe", in: arguments) else {
            fputs("missing --pipe\n", stderr)
            exit(64)
        }

        let descriptor = open(pipePath, O_WRONLY)
        guard descriptor >= 0 else {
            fputs("could not open pipe\n", stderr)
            exit(73)
        }

        signal(SIGPIPE, SIG_IGN)

        let writer = SensorSampleWriter(descriptor: descriptor)
        let sensor = MacBookMotionSensor()

        do {
            try sensor.start { sample in
                writer.write(sample)
            }
            RunLoop.current.run()
        } catch {
            fputs("\(error.localizedDescription)\n", stderr)
            close(descriptor)
            exit(70)
        }
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(arguments.index(after: index)) else {
            return nil
        }

        return arguments[arguments.index(after: index)]
    }
}

private final class SensorSampleWriter: @unchecked Sendable {
    private let descriptor: Int32
    private let encoder = JSONEncoder()
    private let lock = NSLock()

    init(descriptor: Int32) {
        self.descriptor = descriptor
    }

    func write(_ sample: MotionSample) {
        lock.lock()
        defer {
            lock.unlock()
        }

        guard var data = try? encoder.encode(sample) else {
            return
        }

        data.append(0x0A)
        let result = data.withUnsafeBytes { pointer in
            Darwin.write(descriptor, pointer.baseAddress, data.count)
        }

        guard result > 0 else {
            close(descriptor)
            exit(0)
        }
    }
}
