# DoneNow App Store compliance checklist

Last reviewed against Apple's published guidance: 2026-09-18.

## Submission readiness

- Ship a complete, stable build with accurate screenshots, descriptions, age rating, privacy disclosures, support URL and privacy-policy URL.
- Explain non-obvious behavior, MusicKit, local audio import and every in-app purchase in App Review notes. Make all submitted purchases visible and functional for review.
- Use TestFlight for beta distribution. Do not submit a demo or unfinished binary to the App Store.

## Free and Pro

- Release builds must derive Pro access only from verified StoreKit 2 entitlements. The local developer override must remain Debug-only.
- Include Restore Purchases and access to Apple's subscription-management interface where applicable.
- Clearly identify which themes and features require Pro before purchase.
- If Pro is an auto-renewable subscription, it must provide ongoing value, last at least seven days, work across supported user devices, and clearly disclose benefits, duration and price. Otherwise prefer a non-consumable lifetime unlock.

## Music and files

- Request MusicKit permission only when the user chooses Apple Music and provide a clear NSAppleMusicUsageDescription.
- Do not copy, export or convert protected Apple Music content. Use MusicKit playback APIs and handle users without a playable subscription.
- Personal audio import uses the system document picker, validates playback locally, copies only into the app container, and keeps the prior selection if import fails.
- Users are responsible for choosing files they have permission to use; the app does not upload or redistribute imported audio.

## Privacy and safety

- Keep focus sessions and imported audio on-device unless a later feature clearly obtains consent and updates disclosures.
- Publish an easily accessible privacy policy describing collection, sharing, retention, deletion and consent withdrawal—even if no personal data is collected.
- Use only public APIs, truthful claims and necessary permissions with accurate purpose strings.

## Required verification before submission

- Physical-device timer, haptic, MusicKit and audio-format tests.
- iPhone and iPad layout, Dynamic Type, VoiceOver, contrast and reduced-motion review.
- StoreKit sandbox purchase, restore, expiry, refund/revocation, offline and Family Sharing behavior as applicable.
- Crash-free launch and core-flow testing, including denied permissions and unavailable subscriptions.

Apple's rules change. Recheck the current App Review Guidelines, MusicKit documentation, StoreKit documentation and App Store Connect requirements before submission. No checklist can guarantee approval.
