@preconcurrency import AVFoundation
#if canImport(CoreVideo)
import CoreVideo
#endif
import Foundation

public struct SendablePixelBuffer: @unchecked Sendable {
    public let value: CVPixelBuffer

    public init(_ value: CVPixelBuffer) {
        self.value = value
    }
}

public final class CameraCaptureController: NSObject, ObservableObject {
    public enum State: Equatable {
        case idle
        case requestingPermission
        case denied
        case configured
        case failed(String)
    }

    private enum CameraError: LocalizedError {
        case deviceUnavailable
        case inputCreationFailed

        var errorDescription: String? {
            switch self {
            case .deviceUnavailable:
                return "No usable camera was found on this device."
            case .inputCreationFailed:
                return "The camera input could not be configured."
            }
        }
    }

    @Published public private(set) var state: State = .idle

    public let session = AVCaptureSession()
    public var onFrame: ((CVPixelBuffer) -> Void)?

    private let output = AVCaptureVideoDataOutput()
    private let outputQueue = DispatchQueue(label: "CameraCaptureController.output", qos: .userInitiated)
    private let sessionQueue = DispatchQueue(label: "CameraCaptureController.session", qos: .userInitiated)
    private var isConfigured = false

    public func start() async -> State {
        if case .configured = state {
            return state
        }

        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch authorizationStatus {
        case .authorized:
            break
        case .notDetermined:
            state = .requestingPermission
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else {
                state = .denied
                return state
            }
        case .denied, .restricted:
            state = .denied
            return state
        @unknown default:
            state = .failed("Camera authorization is unavailable.")
            return state
        }

        do {
            try await configureSessionIfNeeded()
            try await startRunningSession()
            state = .configured
        } catch {
            state = .failed(error.localizedDescription)
        }

        return state
    }

    public func stop() {
        sessionQueue.async { [session] in
            guard session.isRunning else {
                return
            }

            session.stopRunning()
        }
    }

    private func configureSessionIfNeeded() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: CameraError.inputCreationFailed)
                    return
                }

                guard self.isConfigured == false else {
                    continuation.resume()
                    return
                }

                do {
                    self.session.beginConfiguration()
                    self.session.sessionPreset = .high

                    guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                        ?? AVCaptureDevice.default(for: .video)
                    else {
                        throw CameraError.deviceUnavailable
                    }

                    let input = try AVCaptureDeviceInput(device: device)
                    guard self.session.canAddInput(input) else {
                        throw CameraError.inputCreationFailed
                    }
                    self.session.addInput(input)

                    self.output.alwaysDiscardsLateVideoFrames = true
                    self.output.videoSettings = [
                        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                    ]
                    self.output.setSampleBufferDelegate(self, queue: self.outputQueue)

                    guard self.session.canAddOutput(self.output) else {
                        throw CameraError.inputCreationFailed
                    }
                    self.session.addOutput(self.output)

                    if let connection = self.output.connection(with: .video) {
                        if connection.isVideoOrientationSupported {
                            connection.videoOrientation = .portrait
                        }
                        if connection.isVideoMirroringSupported, device.position == .front {
                            connection.isVideoMirrored = true
                        }
                    }

                    self.session.commitConfiguration()
                    self.isConfigured = true
                    continuation.resume()
                } catch {
                    self.session.commitConfiguration()
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func startRunningSession() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [session] in
                if session.isRunning == false {
                    session.startRunning()
                }
                continuation.resume()
            }
        }
    }
}

extension CameraCaptureController: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        onFrame?(pixelBuffer)
    }
}
