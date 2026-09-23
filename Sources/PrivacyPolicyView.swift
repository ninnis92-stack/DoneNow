import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("DoneNow Privacy Policy")
                        .font(.title.bold())
                    Text("Last updated September 19, 2026")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    policySection("What DoneNow stores", "DoneNow stores your focus preferences, selected clock face, session settings, and imported audio on your device. The app does not require an account and does not upload your focus sessions or imported audio.")
                    policySection("Purchases", "If you buy DoneNow Pro, Apple processes the purchase through StoreKit. DoneNow uses Apple's verified transaction and entitlement APIs to determine access to Pro features. DoneNow does not receive or store your payment details.")
                    policySection("Audio files", "When you choose a file with the system Files picker, DoneNow validates it locally and copies it into the app's private storage for playback. Choose only audio you have permission to use. You can remove imported audio at any time with the Remove control in the Focus Music section.")
                    policySection("Advertising", "The Free version uses Google Mobile Ads to show banner advertising. Depending on your consent choices and regional requirements, Google may process advertising identifiers, diagnostics, and approximate device information to serve or measure ads. DoneNow does not sell your focus sessions or imported audio. DoneNow Pro removes advertising.")
                    policySection("Data sharing and retention", "DoneNow has no account system or server-side storage for your focus sessions or imported audio. Advertising-related data is handled by Google Mobile Ads according to your consent choices and Google's policies. Settings and imported audio remain on the device until you change them or remove the app.")
                    policySection("Changes and contact", "If DoneNow's data practices change, this policy will be updated before the change is released. A public privacy-policy URL and support contact must be added to the App Store product record before submission.")
                }
                .frame(maxWidth: 680, alignment: .leading)
                .padding(24)
            }
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func policySection(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(body).font(.body).foregroundStyle(.secondary)
        }
    }
}
