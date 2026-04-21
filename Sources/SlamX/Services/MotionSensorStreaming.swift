import Foundation
import SlamXCore

protocol MotionSensorStreaming: AnyObject {
    typealias SampleHandler = @Sendable (MotionSample) -> Void

    func start(sampleHandler: @escaping SampleHandler) throws
    func stop()
}
