#if canImport(AVFoundation) && canImport(UIKit)
import AVFoundation
import SwiftUI
import UIKit

public struct CameraPreviewView: UIViewRepresentable {
    public let session: AVCaptureSession

    public init(session: AVCaptureSession) {
        self.session = session
    }

    public func makeUIView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        return view
    }

    public func updateUIView(_ uiView: PreviewContainerView, context: Context) {
        uiView.previewLayer.session = session
    }
}

public final class PreviewContainerView: UIView {
    public override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected AVCaptureVideoPreviewLayer.")
        }
        return layer
    }
}
#endif
