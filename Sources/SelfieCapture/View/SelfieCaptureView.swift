import SwiftUI
import Combine

public struct SelfieCaptureView: View {
    @ObservedObject private var viewModel: SelfieCaptureViewModel
    let camera = CameraView()
    private weak var delegate: SmartSelfieResultDelegate?

    init(viewModel: SelfieCaptureViewModel, delegate: SmartSelfieResultDelegate) {
        self.viewModel = viewModel
        self.delegate = delegate
    }

    // TO-DO: Clean up selfie capture view. Make UI Configurable
    public var body: some View {
        GeometryReader { geometry in
            let ovalSize = ovalSize(from: geometry)
            ZStack {
                camera
                    .onAppear {
                        viewModel.captureResultDelegate = delegate
                        viewModel.faceLayoutGuideFrame =
                        CGRect(origin: .zero,
                               size: ovalSize)
                        viewModel.viewDelegate = camera.preview
                    }

                FaceOverlayView(model: viewModel)
            }
        }.edgesIgnoringSafeArea(.all)
    }

    private func ovalSize(from geometry: GeometryProxy) -> CGSize {
        return CGSize(width: geometry.size.width * 0.7,
                      height: geometry.size.width * 0.7 / (3/3.5))
    }
}

struct SelfieCaptureView_Previews: PreviewProvider {
    static var previews: some View {
        SelfieCaptureView(viewModel: SelfieCaptureViewModel(userId: UUID().uuidString, sessionId: UUID().uuidString, isEnroll: false), delegate: DummyDelegate())
    }
}

class DummyDelegate: SmartSelfieResultDelegate {
    func didSucceed(selfieImage: Data, livenessImages: [Data]) {}
    func didError(error: Error) {}
}