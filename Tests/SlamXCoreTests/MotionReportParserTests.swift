import XCTest
@testable import SlamXCore

final class MotionReportParserTests: XCTestCase {
    func testParsesAppleSPUFixedPointAcceleration() throws {
        let report: [UInt8] = [
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x80, 0x00, 0x00,
            0x00, 0x40, 0xFF, 0xFF,
            0x00, 0x00, 0x01, 0x00,
            0x00, 0x00, 0x00, 0x00
        ]

        let sample = try XCTUnwrap(MotionReportParser.sample(from: report, timestamp: 12.0))

        XCTAssertEqual(sample.timestamp, 12.0)
        XCTAssertEqual(sample.acceleration.x, 0.5)
        XCTAssertEqual(sample.acceleration.y, -0.75)
        XCTAssertEqual(sample.acceleration.z, 1.0)
    }

    func testMotionSampleRoundTripsThroughJSON() throws {
        let sample = MotionSample(
            timestamp: 12.0,
            acceleration: MotionVector(x: 0.5, y: -0.75, z: 1.0),
            rawReport: [0x00, 0x01, 0x02]
        )

        let data = try JSONEncoder().encode(sample)
        let decoded = try JSONDecoder().decode(MotionSample.self, from: data)

        XCTAssertEqual(decoded, sample)
    }
}
