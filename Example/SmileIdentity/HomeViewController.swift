import UIKit
import SwiftUI
import Combine
import SmileID

class HomeViewController: UIViewController, SmartSelfieResultDelegate {
    var cameraVC: UIViewController?
    var cancellable: AnyCancellable?
    var userID = ""
    var currentJob = JobType.smartSelfieEnrollment

    @IBOutlet var versionLabel: CopyableLabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        let partnerID = SmileID.configuration.partnerId
        versionLabel.text = "Partner \(partnerID) - Version \(VersionNames().version)"
    }

    @IBAction func onEnvironmentToggle(_ sender: UIBarButtonItem) {
        if sender.title!.lowercased() == "sandbox" {
            SmileID.setEnvironment(useSandbox: false)
            sender.title = "Production"
        } else {
            SmileID.setEnvironment(useSandbox: true)
            sender.title = "Sandbox"
        }
    }

    @IBAction func onSmartSelfieRegistrationTap(_ sender: Any) {
        userID = UUID().uuidString
        currentJob = .smartSelfieEnrollment
        let smartSelfieRegistrationScreen = SmileID.smartSelfieRegistrationScreen(userId: userID,
                                                                                        delegate: self)
        cameraVC = UIHostingController(rootView: smartSelfieRegistrationScreen)
        cameraVC?.modalPresentationStyle = .fullScreen
        navigationController?.present(cameraVC!, animated: true)
    }

    @IBAction func onSmartSelfieAuthenticationTap(_ sender: Any) {
        currentJob = .smartSelfieAuthentication
    }

    func smartSelfieAuthenticationScreen(userID: String) {
        let smartSelfieAuthenticationScreen = SmileID.smartSelfieAuthenticationScreen(userId: userID,
                                                                                            delegate: self)
        cameraVC = UIHostingController(rootView: smartSelfieAuthenticationScreen)
        cameraVC?.modalPresentationStyle = .fullScreen
        navigationController?.present(cameraVC!, animated: true)
    }

    func didSucceed(selfieImage: Data, livenessImages: [Data], jobStatusResponse: JobStatusResponse) {
        cameraVC?.dismiss(animated: true, completion: {

            switch self.currentJob {
            case .smartSelfieEnrollment:
                UIPasteboard.general.string = self.userID
                self.presentAlert(title: "Smart Selfie Enrollment Complete",
                                  message: "The user has been registered and the user id has been copied to the clipboard.")
            case .smartSelfieAuthentication:
                self.presentAlert(title: "Smart Selfie Authentication Complete",
                                  message: "The user has been authenticated succesfully")
                self.navigationController?.popViewController(animated: true)
            default:
                break
            }
        })
    }

    func presentAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title,
                                                message: message,
                                                preferredStyle: .alert)
        alertController.addAction(.init(title: "Okay", style: .default))
        self.navigationController?.present(alertController, animated: true)
    }

    func didError(error: Error) {
        presentAlert(title: "An error occured", message: error.localizedDescription)
    }
}