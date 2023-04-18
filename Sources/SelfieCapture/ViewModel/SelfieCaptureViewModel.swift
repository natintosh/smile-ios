import Foundation
import UIKit
import Combine

enum SelfieCaptureViewModelAction {

    // scene stabilization action
    case sceneUnstable
    // Face detection actions
    case noFaceDetected
    case multipleFacesDetected
    case faceObservationDetected(FaceGeometryModel)
    case faceQualityObservationDetected(FaceQualityModel)
}

final class SelfieCaptureViewModel: ObservableObject {
    var userId: String
    var sessionId: String
    var isEnroll: Bool
    var faceLayoutGuideFrame = CGRect.zero
    var viewDelegate: FaceDetectorDelegate? {
        didSet {
            faceDetector.viewDelegate = viewDelegate
        }
    }
    private var frameManager = FrameManager.shared
    private var faceDetector = FaceDetector()
    private var subscribers = Set<AnyCancellable>()
    private let numberOfLivenessImages = 7
    private let livenessImageSize = CGSize(width: 256, height: 256)
    private let selfieImageSize = CGSize(width: 320, height: 320)
    private var currentBuffer: CVPixelBuffer?
    private var selfieImage: Data? {
        didSet {
            updateProgress()
        }
    }
    private var livenessImages = [Data]() {
        didSet {
            updateProgress()
        }
    }
    private var lastCaptureTime: Int64 = 0
    private var interCaptureDelay = 350
    weak var captureResultDelegate: SmartSelfieResultDelegate?

    @Published var progress: CGFloat = 0

    @Published private(set) var hasDetectedValidFace: Bool {
        didSet {
            if hasDetectedValidFace {
                captureImage()
            }
        }
    }
    @Published private(set) var isAcceptableRoll: Bool {
        didSet {
            calculateDetectedFaceValidity()
        }
    }
    @Published private(set) var isAcceptableYaw: Bool {
        didSet {
            calculateDetectedFaceValidity()
        }
    }
    @Published private(set) var isAcceptableBounds: FaceBoundsState {
        didSet {
            calculateDetectedFaceValidity()
        }
    }
    @Published private(set) var isAcceptableQuality: Bool {
        didSet {
            calculateDetectedFaceValidity()
        }
    }

    @Published private(set) var faceDetectionState: FaceDetectionState
    @Published private(set) var faceGeometryState: FaceObservation<FaceGeometryModel, ErrorWrapper> {
        didSet {
            processUpdatedFaceGeometry()
        }
    }
    @Published private(set) var faceQualityState: FaceObservation<FaceQualityModel, ErrorWrapper> {
        didSet {
            processUpdatedFaceQuality()
        }
    }

    init(userId: String, sessionId: String, isEnroll: Bool) {
        self.userId = userId
        self.sessionId = sessionId
        self.isEnroll = isEnroll
        faceDetectionState = .noFaceDetected
        isAcceptableRoll = false
        isAcceptableYaw = false
        isAcceptableBounds = .unknown
        isAcceptableQuality = false

        hasDetectedValidFace = false
        faceGeometryState = .faceNotFound
        faceQualityState = .faceNotFound
        faceDetector.model = self
        setupSubscriptions()
    }

    private func setupSubscriptions() {
        frameManager.$sampleBuffer
            .receive(on: DispatchQueue.global())
            .compactMap { return $0 }
            .sink {
                self.faceDetector.detect(pixelBuffer: $0)
                self.currentBuffer = $0
            }
            .store(in: &subscribers)
    }

    func perform(action: SelfieCaptureViewModelAction) {
        switch action {
        case .sceneUnstable:
            publishUnstableSceneObserved()
        case .noFaceDetected:
            publishNoFaceObserved()
        case .multipleFacesDetected:
            publishFaceObservation(.multipleFacesDetected)
        case .faceObservationDetected(let faceGeometry):
            publishFaceObservation(.faceDetected, faceGeometryModel: faceGeometry)
        case .faceQualityObservationDetected(let faceQualityModel):
            publishFaceObservation(.faceDetected, faceQualityModel: faceQualityModel)
        }
    }

    private func captureImage() {
        guard let currentBuffer = currentBuffer, hasDetectedValidFace == true,
              livenessImages.count < numberOfLivenessImages + 1  else {
            return
        }
        guard case let .faceFound(faceGeometry) = faceGeometryState else {
            return
        }
        while (livenessImages.count < numberOfLivenessImages) &&
                ((Date().millisecondsSince1970 - lastCaptureTime) > interCaptureDelay) {
            guard let image = ImageUtils.captureFace(from: currentBuffer,
                                                     faceGeometry: faceGeometry,
                                                     finalSize: livenessImageSize,
                                                     screenImageSize: faceLayoutGuideFrame.size,
                                                     isGreyScale: true) else { return }
            livenessImages.append(image)
            lastCaptureTime = Date().millisecondsSince1970
        }

        if (livenessImages.count == numberOfLivenessImages) &&
            ((Date().millisecondsSince1970 - lastCaptureTime) > interCaptureDelay) &&
            selfieImage == nil {
            publishFaceObservation(.finalFrame)
            guard let selfieImage = ImageUtils.captureFace(from: currentBuffer,
                                                           faceGeometry: faceGeometry,
                                                           finalSize: selfieImageSize,
                                                           screenImageSize: faceLayoutGuideFrame.size,
                                                           isGreyScale: false) else { return }
            lastCaptureTime = Date().millisecondsSince1970
            self.selfieImage = selfieImage
            do {
                let fileUrls = try LocalStorage.saveImageJpg(livenessImages: livenessImages,
                                                                      previewImage: selfieImage,
                                                                      to: sessionId)
                let zipUrl = try LocalStorage.zipFiles(at: fileUrls)
                let zipData = try Data(contentsOf: zipUrl)
                submit(zip: zipData)
            } catch {
                DispatchQueue.main.async { [self] in
                    captureResultDelegate?.didError(error: error)
                }
            }
        }
    }

    func submit(zip: Data) {
        let jobType = isEnroll ? JobType.smartSelfieEnrollment : JobType.smartSelfieAuthentication
        let authRequest = AuthenticationRequest(jobType: jobType, enrollment: isEnroll, userId: userId)

        SmileIdentity.api.authenticate(request: authRequest)
            .flatMap(prepUpload)
            .flatMap ({[self] in upload($0, zip: zip)})
            .sink(receiveCompletion: {completion in
                switch completion {
                case .failure(let error):
                    DispatchQueue.main.async { [self] in
                        captureResultDelegate?.didError(error: error)
                    }
                default:
                    break
                }
            }, receiveValue: { response in
                DispatchQueue.main.async { [self] in
                    handleUploadResponse(response)
                }
            }).store(in: &subscribers)
    }

    private func prepUpload(_ authResponse: AuthenticationResponse) -> AnyPublisher<PrepUploadResponse, Error> {
        let prepUploadRequest = PrepUploadRequest(partnerParams: authResponse.partnerParams,
                                                  timestamp: authResponse.timestamp,
                                                  signature: authResponse.signature)
        return SmileIdentity.api.prepUpload(request: prepUploadRequest)
    }

    private func upload(_ prepUploadResponse: PrepUploadResponse, zip: Data) -> AnyPublisher<UploadResponse, Error> {
        return SmileIdentity.api.upload(zip: zip, to: prepUploadResponse.uploadUrl)
    }

    private func handleUploadResponse(_ response: UploadResponse) {
        switch response {
        case .response:
            captureResultDelegate?.didSucceed(selfieImage: selfieImage ?? Data(),
                                              livenessImages: livenessImages)
        default:
            break
        }
    }

    func saveLivenessImage(data: Data) {
        if let photo = UIImage(data: data) {
            UIImageWriteToSavedPhotosAlbum(photo, nil, nil, nil)
        }
    }

    private func publishUnstableSceneObserved() {
        DispatchQueue.main.async { [self] in
            faceDetectionState = .sceneUnstable
        }
    }

    private func publishNoFaceObserved() {
        DispatchQueue.main.async { [self] in
            faceDetectionState = .noFaceDetected
            faceGeometryState = .faceNotFound
            faceQualityState = .faceNotFound
        }
    }

    private func updateProgress() {
        DispatchQueue.main.async { [self] in
            let selfieImageCount = selfieImage == nil ? 0 : 1
            progress = CGFloat(livenessImages.count+selfieImageCount)/CGFloat(numberOfLivenessImages+1)
        }
    }

    private func publishFaceObservation(_ faceDetectionState: FaceDetectionState,
                                        faceGeometryModel: FaceGeometryModel? = nil,
                                        faceQualityModel: FaceQualityModel? = nil) {
        DispatchQueue.main.async { [self] in
            self.faceDetectionState = faceDetectionState
            if let faceGeometryModel = faceGeometryModel {
                faceGeometryState = .faceFound(faceGeometryModel)
            }
            if let faceQualityModel = faceQualityModel {
                faceQualityState = .faceFound(faceQualityModel)
            }
        }
    }

    func processUpdatedFaceGeometry() {
        switch faceGeometryState {
        case .faceNotFound:
            invalidateFaceGeometryState()
        case .errored(let errorWrapper):
            print(errorWrapper.error.localizedDescription)
            invalidateFaceGeometryState()
        case .faceFound(let faceGeometryModel):
            let boundingBox = faceGeometryModel.boundingBox
            let roll = faceGeometryModel.roll.doubleValue
            let yaw = faceGeometryModel.yaw.doubleValue
            updateAcceptableBounds(using: boundingBox)
            updateAcceptableRollYaw(using: roll, yaw: yaw)
        }
    }
}

extension SelfieCaptureViewModel {
    func invalidateFaceGeometryState() {
        isAcceptableRoll = false
        isAcceptableYaw = false
        isAcceptableBounds = .unknown
    }

    func calculateDetectedFaceValidity() {
        hasDetectedValidFace =
        isAcceptableBounds == .detectedFaceAppropriateSizeAndPosition &&
        isAcceptableRoll &&
        isAcceptableYaw &&
        isAcceptableQuality
    }

    func updateAcceptableBounds(using boundingBox: CGRect) {
        if boundingBox.width > 0.7 * faceLayoutGuideFrame.width {
            isAcceptableBounds = .detectedFaceTooLarge
        } else if boundingBox.width < faceLayoutGuideFrame.width * 0.25 {
            isAcceptableBounds = .detectedFaceTooSmall
        } else {
            if abs(boundingBox.midX - faceLayoutGuideFrame.midX) > 50 {
                isAcceptableBounds = .detectedFaceOffCentre
            } else if abs(boundingBox.midY - faceLayoutGuideFrame.midY) > 50 {
                isAcceptableBounds = .detectedFaceOffCentre
            } else {
                isAcceptableBounds = .detectedFaceAppropriateSizeAndPosition
            }
        }
    }

    func updateAcceptableRollYaw(using roll: Double, yaw: Double) {
        isAcceptableRoll = abs(roll) < 0.5
        isAcceptableYaw = abs(CGFloat(yaw)) < 0.15
    }

    func processUpdatedFaceQuality() {
        switch faceQualityState {
        case .faceNotFound:
            isAcceptableQuality = false
        case .errored(let errorWrapper):
            print(errorWrapper.error.localizedDescription)
            isAcceptableQuality = false
        case .faceFound(let faceQualityModel):
            if faceQualityModel.quality < 0.3 {
                isAcceptableQuality = false
            }
            isAcceptableQuality = true
        }
    }
}