import SwiftUI

#if canImport(GoogleMobileAds)
import GoogleMobileAds

final class AttachedBannerView: BannerView {
    private var requested = false

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !requested, let controller = window?.rootViewController else { return }
        rootViewController = controller
        requested = true
        requestAd()
    }

    var requestAd: () -> Void = {}
}

private struct GoogleBannerView: UIViewRepresentable {
    let onFailure: () -> Void

    final class Coordinator: NSObject, BannerViewDelegate {
        let onFailure: () -> Void

        init(onFailure: @escaping () -> Void) {
            self.onFailure = onFailure
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            DispatchQueue.main.async {
                self.onFailure()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onFailure: onFailure)
    }

    func makeUIView(context: Context) -> BannerView {
        let view = AttachedBannerView(adSize: AdSizeBanner)
        view.adUnitID = "ca-app-pub-9920152861798489/9758109472"
        view.delegate = context.coordinator
        view.requestAd = { [weak view] in view?.load(Request()) }
        return view
    }

    func updateUIView(_ view: BannerView, context: Context) {
        // Loading begins when the banner actually joins a window.
    }
}
#endif

struct AdBannerSlot: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let consentReady: Bool
    let statusMessage: String?
    let retry: () -> Void
    var upgrade: () -> Void
    @State private var liveAdFailed = false

    var body: some View {
        Group {
            #if canImport(GoogleMobileAds)
            if consentReady && !liveAdFailed {
                GoogleBannerView {
                    liveAdFailed = true
                }
                    .frame(height: 50)
                    .clipped()
                    .accessibilityLabel("Advertisement")
            } else {
                houseAd
            }
            #else
            houseAd
            #endif
        }
        .frame(maxWidth: .infinity)
    }

    private var houseAd: some View {
        VStack(spacing: 6) {
            Button(action: upgrade) {
                if dynamicTypeSize.isAccessibilitySize {
                    Label("View Pro", systemImage: "sparkles")
                        .font(.body.weight(.semibold))
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                } else {
                HStack(spacing: 12) {
                    #if DEBUG
                    Text("AD PREVIEW")
                        .font(.system(size: 8, weight: .bold))
                        .padding(5)
                        .background(.white.opacity(0.12), in: Capsule())
                    #endif
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Focus without interruptions")
                            .font(.subheadline.weight(.semibold))
                        Text("Upgrade to Pro for an ad-free experience")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("View Pro")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.cyan)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View DoneNow Pro and remove the Free plan banner")

            if statusMessage != nil || liveAdFailed {
                    Button("Retry ad setup", action: retryAds)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Retry advertisement setup")
            }
        }
    }

    private func retryAds() {
        liveAdFailed = false
        retry()
    }
}
