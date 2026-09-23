import Foundation
import GoogleMobileAds
import UserMessagingPlatform

@MainActor
final class AdMobCoordinator: ObservableObject {
    static let shared = AdMobCoordinator()

    @Published private(set) var canRequestAds = false
    @Published private(set) var statusMessage: String?
    @Published private(set) var privacyOptionsRequired = false
    @Published private(set) var consentRevision = UUID()
    private var hasStarted = false
    private var isStarting = false

    private init() {}

    func start() {
        guard !hasStarted, !isStarting else { return }
        isStarting = true

        let parameters = RequestParameters()
        ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { [weak self] error in
            guard let self else { return }
            if error != nil {
                Task { @MainActor in
                    self.isStarting = false
                    self.privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
                    if ConsentInformation.shared.canRequestAds {
                        self.hasStarted = true
                        self.canRequestAds = true
                        self.statusMessage = nil
                        await MobileAds.shared.start()
                    } else {
                        self.statusMessage = "Ad setup is temporarily unavailable."
                    }
                }
                return
            }

            ConsentForm.loadAndPresentIfRequired(from: nil) { [weak self] formError in
                guard let self else { return }
                Task { @MainActor in
                    self.isStarting = false
                    self.privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
                    self.hasStarted = true
                    self.canRequestAds = ConsentInformation.shared.canRequestAds
                    if self.canRequestAds {
                        self.statusMessage = nil
                        await MobileAds.shared.start()
                    } else if formError != nil {
                        self.statusMessage = "Ad consent could not be completed. You can retry from the banner."
                    }
                }
            }
        }
    }

    func retry() {
        hasStarted = false
        canRequestAds = false
        statusMessage = nil
        start()
    }

    func showPrivacyOptions() {
        ConsentForm.presentPrivacyOptionsForm(from: nil) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                self.canRequestAds = ConsentInformation.shared.canRequestAds
                self.privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
                self.statusMessage = error == nil ? nil : "Privacy options could not be opened. Please try again."
                self.consentRevision = UUID()
            }
        }
    }
}
