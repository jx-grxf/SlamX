import Foundation
import SlamXCore

enum PrivilegedMotionSensorError: LocalizedError {
    case executableUnavailable
    case helperLaunchFailed(String)
    case pipeCreationFailed
    case pipeOpenFailed

    var errorDescription: String? {
        switch self {
        case .executableUnavailable:
            "SlamX could not locate its sensor helper executable."
        case .helperLaunchFailed(let detail):
            "The privileged sensor helper could not be started. \(detail)"
        case .pipeCreationFailed:
            "SlamX could not create the local sensor pipe."
        case .pipeOpenFailed:
            "SlamX could not open the local sensor pipe."
        }
    }
}

final class PrivilegedMotionSensor: MotionSensorStreaming, @unchecked Sendable {
    private let fileManager = FileManager.default
    private let lineBufferLock = NSLock()
    private var pipeHandle: FileHandle?
    private var sessionDirectory: URL?
    private var lineBuffer = Data()

    func start(sampleHandler: @escaping SampleHandler) throws {
        stop()

        guard let executablePath = Bundle.main.executablePath else {
            throw PrivilegedMotionSensorError.executableUnavailable
        }

        let sessionDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("slamx-\(getuid())-\(UUID().uuidString)", isDirectory: true)
        let pipeURL = sessionDirectory.appendingPathComponent("sensor.pipe")

        try fileManager.createDirectory(
            at: sessionDirectory,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )

        guard mkfifo(pipeURL.path, S_IRUSR | S_IWUSR) == 0 else {
            cleanup(sessionDirectory)
            throw PrivilegedMotionSensorError.pipeCreationFailed
        }

        do {
            _ = try launchHelper(executablePath: executablePath, pipePath: pipeURL.path)
        } catch {
            cleanup(sessionDirectory)
            throw error
        }

        let descriptor = open(pipeURL.path, O_RDONLY | O_NONBLOCK)
        guard descriptor >= 0 else {
            cleanup(sessionDirectory)
            throw PrivilegedMotionSensorError.pipeOpenFailed
        }

        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        self.pipeHandle = handle
        self.sessionDirectory = sessionDirectory

        handle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                return
            }

            self?.consume(data, sampleHandler: sampleHandler)
        }
    }

    func stop() {
        pipeHandle?.readabilityHandler = nil
        pipeHandle?.closeFile()
        pipeHandle = nil

        lineBufferLock.lock()
        lineBuffer.removeAll(keepingCapacity: false)
        lineBufferLock.unlock()

        if let sessionDirectory {
            cleanup(sessionDirectory)
            self.sessionDirectory = nil
        }
    }

    private func launchHelper(executablePath: String, pipePath: String) throws -> String {
        let command = [
            shellQuoted(executablePath),
            "--sensor-helper",
            "--pipe",
            shellQuoted(pipePath),
            ">",
            "/dev/null",
            "2>&1",
            "&",
            "echo",
            "$!"
        ].joined(separator: " ")

        let script = "do shell script \(appleScriptQuoted(command)) with administrator privileges"
        let process = Process()
        let output = Pipe()
        let errorOutput = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = output
        process.standardError = errorOutput

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw PrivilegedMotionSensorError.helperLaunchFailed(error.localizedDescription)
        }

        let standardOutput = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let standardError = String(data: errorOutput.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0, !standardOutput.isEmpty else {
            throw PrivilegedMotionSensorError.helperLaunchFailed(standardError)
        }

        return standardOutput
    }

    private func consume(_ data: Data, sampleHandler: @escaping SampleHandler) {
        lineBufferLock.lock()
        defer {
            lineBufferLock.unlock()
        }

        lineBuffer.append(data)

        while let newline = lineBuffer.firstIndex(of: 0x0A) {
            let line = lineBuffer[..<newline]
            lineBuffer.removeSubrange(...newline)

            guard !line.isEmpty,
                  let sample = try? JSONDecoder().decode(MotionSample.self, from: Data(line)) else {
                continue
            }

            sampleHandler(sample)
        }
    }

    private func cleanup(_ directory: URL) {
        try? fileManager.removeItem(at: directory)
    }

    private func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func appleScriptQuoted(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
