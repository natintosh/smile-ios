import Foundation
import Combine
import UIKit
import SmileID

class HomeViewModel: ObservableObject, SmartSelfieResultDelegate, DocumentCaptureResultDelegate {
    @Published var product: JobType? {
        didSet {
            switch product {
            case .smartSelfieEnrollment:
                presentSmartSelfieAuth = false
                presentSmartSelfieEnrollment = true
                presentDocumentVerification = false
            case .smartSelfieAuthentication:
                presentSmartSelfieAuth = true
                presentSmartSelfieEnrollment = false
                presentDocumentVerification = false
            case .documentVerification:
                presentSmartSelfieAuth = false
                presentSmartSelfieEnrollment = false
                presentDocumentVerification = true
            default:
                presentSmartSelfieAuth = false
                presentSmartSelfieEnrollment = false
                presentDocumentVerification = false
            }
        }
    }
    @Published var presentSmartSelfieAuth = false
    @Published var presentSmartSelfieEnrollment = false
    @Published var presentDocumentVerification = false
    @Published var dismissed = false
    @Published var toastMessage = ""
    @Published var showToast = false


    private var userID = ""
    var returnedUserID = ""

    init() {
       subscribeToAuthCompletion()
    }

    func generateUserID() -> String {
        userID = UUID().uuidString
        return userID
    }

    func handleSmartSelfieEnrolmentTap() {
        self.product = .smartSelfieEnrollment
    }

    func handleSmartSelfieAuthTap() {
        self.product = .smartSelfieAuthentication
    }
    
    func handleDocumentVerificationTap() {
        self.product = .documentVerification
    }

    func didSucceed(selfieImage: Data, livenessImages: [Data], jobStatusResponse: JobStatusResponse) {
        returnedUserID = userID
        UIPasteboard.general.string = returnedUserID
        toastMessage = "Smart selfie enrollment completed successfully and the user id has beed copied to the clipboard"
        showToast = true
    }

    @objc func didError(error: Error) {
        toastMessage = error.localizedDescription
        showToast = true
    }

    func subscribeToAuthCompletion() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleAuthCompletion), name: Notification.Name(rawValue: "SelfieCaptureComplete"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAuthCompletion), name: Notification.Name(rawValue: "SelfieCaptureError"), object: nil)
    }

    @objc func handleAuthCompletion(_ notification: NSNotification) {
        print("Its done")
        toastMessage = "Smart selfie Authenticaion completed successfully"
        showToast = true
    }
}
