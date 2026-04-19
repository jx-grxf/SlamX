import Foundation

public struct MotionVector: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    public var magnitude: Double {
        sqrt(x * x + y * y + z * z)
    }

    public func distance(to other: MotionVector) -> Double {
        let dx = x - other.x
        let dy = y - other.y
        let dz = z - other.z
        return sqrt(dx * dx + dy * dy + dz * dz)
    }
}

public struct MotionSample: Codable, Equatable, Sendable {
    public let timestamp: TimeInterval
    public let acceleration: MotionVector
    public let rawReport: [UInt8]

    public init(timestamp: TimeInterval, acceleration: MotionVector, rawReport: [UInt8]) {
        self.timestamp = timestamp
        self.acceleration = acceleration
        self.rawReport = rawReport
    }
}
